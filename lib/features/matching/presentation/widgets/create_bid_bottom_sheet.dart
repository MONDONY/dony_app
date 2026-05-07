import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _contentCategories = [
  'Vêtements',
  'Médicaments',
  'Alim. sèche',
  'Documents',
  'Hi-fi',
  'Téléphone',
  'Autre',
];

const _kAccentBorder = 3.0; // disclaimer card left accent border width

class CreateBidBottomSheet {
  static Future<void> show(
    BuildContext context, {
    required AnnouncementModel announcement,
  }) {
    return DonyBottomSheet.show(
      context,
      title: 'Envoyer un colis',
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => getIt<BidBloc>()),
          BlocProvider(create: (_) => getIt<PaymentBloc>()),
        ],
        child: _CreateBidContent(announcement: announcement),
      ),
    );
  }
}

// ─── Content widget ───────────────────────────────────────────────────────────

class _CreateBidContent extends StatefulWidget {
  const _CreateBidContent({required this.announcement});

  final AnnouncementModel announcement;

  @override
  State<_CreateBidContent> createState() => _CreateBidContentState();
}

class _CreateBidContentState extends State<_CreateBidContent> {
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();

  // ValueNotifiers replace setState for reactive UI — no setState needed
  late final ValueNotifier<double> _weightNotifier;
  final _categoriesNotifier = ValueNotifier<Set<String>>({});
  final _disclaimerNotifier = ValueNotifier<bool>(false);

  double get _maxKg => widget.announcement.availableKg;
  double get _pricePerKg => widget.announcement.pricePerKg;

  @override
  void initState() {
    super.initState();
    _weightNotifier = ValueNotifier<double>(
      widget.announcement.availableKg >= 5 ? 5 : widget.announcement.availableKg,
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _weightNotifier.dispose();
    _categoriesNotifier.dispose();
    _disclaimerNotifier.dispose();
    super.dispose();
  }

  void _submit() {
    if (_descCtrl.text.trim().isEmpty) {
      _showError('Description obligatoire');
      return;
    }
    final val = double.tryParse(_valueCtrl.text);
    if (val == null || val <= 0) {
      _showError('Valeur déclarée invalide');
      return;
    }
    if (val > 500) {
      _showError('Valeur maximum : 500 €');
      return;
    }
    if (_recipientNameCtrl.text.trim().isEmpty) {
      _showError('Nom du destinataire obligatoire');
      return;
    }
    if (_recipientPhoneCtrl.text.trim().isEmpty) {
      _showError('Téléphone du destinataire obligatoire');
      return;
    }
    context.read<BidBloc>().add(BidCheckoutRequested(
      announcementId: widget.announcement.id,
      weightKg: _weightNotifier.value,
      declaredValueEur: val,
      description: _descCtrl.text.trim(),
      contentCategory: _categoriesNotifier.value.join(', '),
      recipientName: _recipientNameCtrl.text.trim(),
      recipientPhone: _recipientPhoneCtrl.text.trim(),
    ));
  }

  void _showError(String message) {
    DonySnackbar.show(context, message: message, type: DonySnackbarType.error);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BidBloc, BidState>(
          listener: (context, state) {
            if (state is BidCheckoutReady) {
              context.read<PaymentBloc>().add(BidCheckoutPaymentRequested(
                clientSecret: state.response.clientSecret,
                publishableKey: state.response.publishableKey,
                bidId: state.response.bidId,
              ));
            } else if (state is BidError) {
              _showError(state.message);
            }
          },
        ),
        BlocListener<PaymentBloc, PaymentState>(
          listener: (context, state) async {
            if (state is CheckoutPaymentSheetReady) {
              await _presentPaymentSheet(context, state);
            }
          },
        ),
      ],
      child: BlocBuilder<BidBloc, BidState>(
        builder: (context, bidState) {
          final isLoading = bidState is BidLoading;
          return ListenableBuilder(
            listenable: Listenable.merge([
              _weightNotifier,
              _categoriesNotifier,
              _disclaimerNotifier,
            ]),
            builder: (context, _) {
              final weightKg = _weightNotifier.value;
              final categories = _categoriesNotifier.value;
              final disclaimerAccepted = _disclaimerNotifier.value;
              final serviceFee = weightKg * _pricePerKg * 0.12;
              final basePrice = weightKg * _pricePerKg;
              final totalPrice = basePrice + serviceFee;
              final canSubmit =
                  weightKg > 0 && categories.isNotEmpty && disclaimerAccepted;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SECTION: Poids estimé ───────────────────────────────
                  _SectionLabel(label: 'POIDS ESTIMÉ'),
                  const SizedBox(height: DonySpacing.sm),
                  _WeightSection(
                    weightKg: weightKg,
                    maxKg: _maxKg,
                    onChanged: (v) => _weightNotifier.value = v,
                  ).animate().fadeIn(duration: 250.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // ── SECTION: Contenu du colis ───────────────────────────
                  _SectionLabel(label: 'CONTENU DU COLIS'),
                  const SizedBox(height: DonySpacing.md),
                  Wrap(
                    spacing: DonySpacing.sm,
                    runSpacing: DonySpacing.sm,
                    children: _contentCategories
                        .map((cat) => _CategoryChip(
                              label: cat,
                              selected: categories.contains(cat),
                              onTap: () {
                                final updated = Set<String>.from(categories);
                                if (updated.contains(cat)) {
                                  updated.remove(cat);
                                } else {
                                  updated.add(cat);
                                }
                                _categoriesNotifier.value = updated;
                              },
                            ))
                        .toList(),
                  ).animate().fadeIn(delay: 60.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // ── SECTION: Description ────────────────────────────────
                  _SectionLabel(label: 'DESCRIPTION (AU VOYAGEUR)'),
                  const SizedBox(height: DonySpacing.sm),
                  DonyTextField(
                    controller: _descCtrl,
                    hint: 'Médicaments pour diabète + 2 tee-shirts enfants',
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // ── Valeur déclarée ─────────────────────────────────────
                  _SectionLabel(label: 'VALEUR DÉCLARÉE (€)'),
                  const SizedBox(height: DonySpacing.sm),
                  TextFormField(
                    controller: _valueCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      hintText: '120',
                      helperText:
                          'Plafond : 500 € — couvre l\'assurance en cas de sinistre',
                      helperStyle: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: DonyColors.neutral400),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.md,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ).animate().fadeIn(delay: 140.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // ── Destinataire ────────────────────────────────────────
                  _SectionLabel(label: 'DESTINATAIRE'),
                  const SizedBox(height: DonySpacing.md),
                  DonyTextField(
                    controller: _recipientNameCtrl,
                    label: 'Prénom et nom du destinataire',
                    hint: 'ex: Amadou Diallo',
                  ).animate().fadeIn(delay: 160.ms),
                  const SizedBox(height: DonySpacing.md),
                  DonyTextField(
                    controller: _recipientPhoneCtrl,
                    label: 'Téléphone du destinataire',
                    hint: 'ex: +221 77 000 00 00',
                    keyboardType: TextInputType.phone,
                  ).animate().fadeIn(delay: 180.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // ── Disclaimer card ─────────────────────────────────────
                  _DisclaimerCard(
                    accepted: disclaimerAccepted,
                    onChanged: (v) => _disclaimerNotifier.value = v,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // ── Price breakdown ─────────────────────────────────────
                  _PriceBreakdown(
                    weightKg: weightKg,
                    pricePerKg: _pricePerKg,
                    basePrice: basePrice,
                    serviceFee: serviceFee,
                    totalPrice: totalPrice,
                  ),
                  const SizedBox(height: DonySpacing.md),

                  // ── CTA ─────────────────────────────────────────────────
                  DonyButton(
                    label: 'Bloquer ${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(totalPrice)} & envoyer',
                    onPressed: canSubmit && !isLoading ? _submit : null,
                    isLoading: isLoading,
                    icon: Icons.lock_rounded,
                  ),
                  const SizedBox(height: DonySpacing.base),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _presentPaymentSheet(
    BuildContext context,
    CheckoutPaymentSheetReady state,
  ) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: state.clientSecret,
          merchantDisplayName: 'Dony',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (!context.mounted) return;
      // Synchronously confirm the payment with the backend so the bid is
      // promoted to PENDING immediately (does not depend on the Stripe webhook).
      context.read<BidBloc>().add(BidConfirmPaymentRequested(state.bidId));
      // Close the bottom sheet first, then navigate to bid detail.
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        // ?from=payment makes the bid-detail back arrow route to /home (mes envois)
        // instead of popping back to the just-completed checkout form.
        unawaited(context.push('/bids/${state.bidId}?from=payment'));
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        _showError('Paiement annulé');
      } else {
        _showError('Erreur de paiement: ${e.error.message}');
      }
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
    }
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(color: DonyColors.neutral400),
    );
  }
}

// ── Weight section with slider ────────────────────────────────────────────────

class _WeightSection extends StatelessWidget {
  const _WeightSection({
    required this.weightKg,
    required this.maxKg,
    required this.onChanged,
  });

  final double weightKg;
  final double maxKg;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        // Large weight display
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              weightKg.toStringAsFixed(0),
              style: tt.displayLarge?.copyWith(color: DonyColors.ink900),
            ),
            const SizedBox(width: DonySpacing.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm),
              child: Text(
                'kg',
                style: tt.headlineMedium?.copyWith(color: DonyColors.neutral400),
              ),
            ),
            const Spacer(),
            Text(
              'max ${maxKg.toStringAsFixed(0)} kg',
              style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: DonyColors.primary,
            inactiveTrackColor: DonyColors.neutral200,
            thumbColor: DonyColors.primary,
            overlayColor: DonyColors.primary.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: weightKg,
            min: 1,
            max: maxKg,
            divisions: (maxKg - 1).round(),
            onChanged: onChanged,
          ),
        ),
        // Range labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1 kg',
              style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
            ),
            Text(
              '${maxKg.toStringAsFixed(0)} kg',
              style: tt.bodySmall?.copyWith(color: DonyColors.neutral400),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Category chip ──────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? DonyColors.ink900 : DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(
            color: selected ? DonyColors.ink900 : DonyColors.neutral200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 14, color: DonyColors.white),
              const SizedBox(width: DonySpacing.xxs),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: selected ? DonyColors.white : DonyColors.ink900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Disclaimer card ───────────────────────────────────────────────────────────

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({
    required this.accepted,
    required this.onChanged,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: DonyColors.terra50,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: const Border(
          left: BorderSide(color: DonyColors.terra500, width: _kAccentBorder),
        ),
      ),
      padding: const EdgeInsets.all(DonySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: DonyColors.terra500,
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disclaimer douane.',
                      style: tt.titleMedium?.copyWith(color: DonyColors.terra700),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      'Pas d\'armes, drogues, liquides inflammables ou espèces. '
                      'Le voyageur peut refuser au contrôle douanier.',
                      style: tt.bodySmall
                          ?.copyWith(color: DonyColors.terra700, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          GestureDetector(
            onTap: () => onChanged(!accepted),
            child: Row(
              children: [
                Checkbox(
                  value: accepted,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: DonyColors.terra500,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    'Je signe & j\'accepte',
                    style: tt.bodySmall?.copyWith(
                      color: DonyColors.ink900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Price breakdown ───────────────────────────────────────────────────────────

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({
    required this.weightKg,
    required this.pricePerKg,
    required this.basePrice,
    required this.serviceFee,
    required this.totalPrice,
  });

  final double weightKg;
  final double pricePerKg;
  final double basePrice;
  final double serviceFee;
  final double totalPrice;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.neutral200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${weightKg.toStringAsFixed(0)} kg × '
                '${pricePerKg.toStringAsFixed(0)}€',
                style: tt.bodyMedium,
              ),
              Text(fmt.format(basePrice), style: tt.titleMedium),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frais de service',
                style: tt.bodyMedium?.copyWith(color: DonyColors.neutral400),
              ),
              Text(fmt.format(serviceFee), style: tt.bodyMedium),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          const Divider(color: DonyColors.neutral200),
          const SizedBox(height: DonySpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: tt.titleLarge),
              Text(
                fmt.format(totalPrice),
                style: tt.titleLarge?.copyWith(color: DonyColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
