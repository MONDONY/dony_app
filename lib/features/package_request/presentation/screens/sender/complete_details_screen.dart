import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/complete_details_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Sender step before paying a negotiated trip: a read-only recap of everything
/// already known (corridor, trip date, weight, parcel size, content, agreed
/// price) + the only things still to provide — the recipient and the payment
/// method (constrained to what's accepted for the request).
///
/// On success the screen pops the chosen [PaymentMethod] so the caller
/// (`ThreadStateCtaBar`) can open the payment recap with that method.
class CompleteDetailsScreen extends StatelessWidget {
  const CompleteDetailsScreen({
    required this.requestId,
    this.thread,
    super.key,
  });
  final String requestId;
  final NegotiationThread? thread;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CompleteDetailsBloc>(
      create: (_) =>
          getIt<CompleteDetailsBloc>()..add(CompleteDetailsStarted(requestId)),
      child: _CompleteDetailsView(requestId: requestId, thread: thread),
    );
  }
}

class _CompleteDetailsView extends StatefulWidget {
  const _CompleteDetailsView({required this.requestId, this.thread});
  final String requestId;
  final NegotiationThread? thread;

  @override
  State<_CompleteDetailsView> createState() => _CompleteDetailsViewState();
}

class _CompleteDetailsViewState extends State<_CompleteDetailsView> {
  final _form = GlobalKey<FormState>();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _recipientCityCtrl = TextEditingController();
  final _declaredValueCtrl = TextEditingController();

  /// Payment method chosen by the sender (null until the request is loaded and
  /// the default is resolved from the accepted methods).
  final _selectedMethod = ValueNotifier<PaymentMethod?>(null);

  @override
  void dispose() {
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _recipientCityCtrl.dispose();
    _declaredValueCtrl.dispose();
    _selectedMethod.dispose();
    super.dispose();
  }

  /// Default = the method the traveler picked at link time (if still accepted),
  /// else Stripe if accepted, else the first accepted method.
  void _resolveDefaultMethod(PackageRequest request) {
    if (_selectedMethod.value != null) return;
    final accepted = request.acceptedPaymentMethods;
    final fromThread = widget.thread?.paymentMethod;
    if (fromThread != null && accepted.contains(fromThread)) {
      _selectedMethod.value = fromThread;
    } else if (accepted.contains(PaymentMethod.stripe)) {
      _selectedMethod.value = PaymentMethod.stripe;
    } else if (accepted.isNotEmpty) {
      _selectedMethod.value = accepted.first;
    } else {
      _selectedMethod.value = fromThread ?? PaymentMethod.stripe;
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final city = _recipientCityCtrl.text.trim();
    final declared = double.parse(
      _declaredValueCtrl.text.trim().replaceAll(',', '.'),
    );
    context.read<CompleteDetailsBloc>().add(
      CompleteDetailsSubmitted(
        requestId: widget.requestId,
        recipientName: _recipientNameCtrl.text.trim(),
        recipientPhone: _recipientPhoneCtrl.text.trim(),
        recipientCity: city.isEmpty ? null : city,
        declaredValueEur: declared,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CompleteDetailsBloc, CompleteDetailsState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.request != curr.request,
      listener: (context, state) {
        if (state.request != null) {
          _resolveDefaultMethod(state.request!);
        }
        if (state.status == CompleteDetailsStatus.success) {
          DonySnackbar.show(
            context,
            message: 'Détails enregistrés',
            type: DonySnackbarType.success,
          );
          // Return the chosen method so the caller opens the payment recap with it.
          final method =
              _selectedMethod.value ??
              widget.thread?.paymentMethod ??
              PaymentMethod.stripe;
          context.pop(method);
        } else if (state.status == CompleteDetailsStatus.error) {
          DonySnackbar.show(
            context,
            message: state.errorMessage ?? 'Erreur',
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: const DonyAppBar(title: 'Vérifie & complète'),
          body: !state.loaded
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        DonySpacing.lg,
                        DonySpacing.xl,
                        DonySpacing.lg,
                        MediaQuery.of(context).padding.bottom + 100,
                      ),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state.request != null) ...[
                              _RecapCard(
                                request: state.request!,
                                thread: widget.thread,
                              ),
                              const SizedBox(height: DonySpacing.xl),
                            ],
                            _section('Destinataire'),
                            TextFormField(
                              controller: _recipientNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nom complet',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: DonySpacing.md),
                            TextFormField(
                              controller: _recipientPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone',
                                hintText: '+221771234567',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Requis';
                                }
                                if (!RegExp(
                                  r'^\+[1-9]\d{6,14}$',
                                ).hasMatch(v.trim())) {
                                  return 'Format E.164 (+221…)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: DonySpacing.md),
                            TextFormField(
                              controller: _recipientCityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ville / commune',
                                hintText: 'Ex. Dakar (optionnel)',
                              ),
                            ),
                            const SizedBox(height: DonySpacing.md),
                            TextFormField(
                              key: const Key('declared-value-input'),
                              controller: _declaredValueCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Valeur déclarée du colis',
                                hintText: 'Ex. 120 (max 500 €)',
                                suffixText: '€',
                              ),
                              validator: (v) {
                                final d = double.tryParse(
                                  (v ?? '').trim().replaceAll(',', '.'),
                                );
                                if (d == null) return 'Valeur requise';
                                if (d <= 0) return 'Doit être positive';
                                if (d > 500) return 'Maximum 500 €';
                                return null;
                              },
                            ),
                            if (state.request != null &&
                                state
                                    .request!
                                    .acceptedPaymentMethods
                                    .isNotEmpty) ...[
                              const SizedBox(height: DonySpacing.xl),
                              _section('Mode de paiement'),
                              ValueListenableBuilder<PaymentMethod?>(
                                valueListenable: _selectedMethod,
                                builder: (context, selected, _) =>
                                    _PaymentMethodChoice(
                                      methods:
                                          state.request!.acceptedPaymentMethods,
                                      selected: selected,
                                      onChanged: (m) =>
                                          _selectedMethod.value = m,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: MediaQuery.of(context).padding.bottom + 20,
                      child: DonyButton(
                        label: state.isLoading
                            ? 'Envoi…'
                            : 'Continuer vers le paiement',
                        isLoading: state.isLoading,
                        onPressed: state.isLoading ? null : _submit,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: DonySpacing.sm),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: kTextSecondary,
        letterSpacing: 1.2,
      ),
    ),
  );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null;
}

String _sizeLabel(ParcelSize s) => switch (s) {
  ParcelSize.small => 'Petit',
  ParcelSize.medium => 'Moyen',
  ParcelSize.large => 'Grand',
};

/// Read-only recap of everything already known about the shipment + trip.
class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.request, this.thread});
  final PackageRequest request;
  final NegotiationThread? thread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final double? gross = thread != null
        ? (thread!.grossPriceEur ??
              PriceDisplay.grossFromNet(thread!.currentPriceEur))
        : request.targetPriceEur;

    final rows = <(String, String)>[
      ('Trajet', '${request.departureCity} → ${request.arrivalCity}'),
      if (thread != null)
        (
          'Date du voyage',
          DateFormat('d MMM yyyy', 'fr').format(thread!.travelerTravelDate),
        ),
      (
        'Poids',
        '${request.weightKg.toStringAsFixed(request.weightKg % 1 == 0 ? 0 : 1)} kg',
      ),
      ('Taille', _sizeLabel(request.parcelSize)),
      if (request.categories.isNotEmpty)
        ('Contenu', request.categories.join(', ')),
      if (gross != null) ('Prix à payer', PriceDisplay.eur(gross)),
    ];

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DonyEmoji.parcel(size: 16),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Récapitulatif',
                style: tt.bodyMedium!.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      r.$1,
                      style: tt.bodySmall?.copyWith(
                        color: kTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: tt.bodyMedium?.copyWith(
                        color: kTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Payment method selector constrained to the request's accepted methods.
/// A single accepted method renders as a read-only chip (no choice).
class _PaymentMethodChoice extends StatelessWidget {
  const _PaymentMethodChoice({
    required this.methods,
    required this.selected,
    required this.onChanged,
  });

  final Set<PaymentMethod> methods;
  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod> onChanged;

  String _icon(PaymentMethod m) => switch (m) {
    PaymentMethod.stripe => 'credit-card',
    PaymentMethod.cash => 'banknote',
    PaymentMethod.wave => 'waves',
    PaymentMethod.orangeMoney => 'smartphone',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Canonical order: STRIPE, CASH, then others.
    final ordered = [
      PaymentMethod.stripe,
      PaymentMethod.cash,
      PaymentMethod.wave,
      PaymentMethod.orangeMoney,
    ].where(methods.contains).toList();

    final single = ordered.length <= 1;

    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: ordered.map((method) {
        final isSelected = selected == method;
        return GestureDetector(
          key: Key('complete-pay-${method.wireName.toLowerCase()}'),
          onTap: single ? null : () => onChanged(method),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected ? cs.primaryContainer : cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.full),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DonyIcon(
                  _icon(method),
                  size: 14,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  method.displayLabel,
                  style: tt.labelMedium?.copyWith(
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (single && isSelected) ...[
                  const SizedBox(width: DonySpacing.xs),
                  DonyIcon('check', size: 14, color: cs.primary),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
