import 'dart:async';

import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/payments/data/stripe_payment_sheet_params.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_quote_response.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Layout constants
// _kScrollPad removed — bottom padding is now dynamic (MediaQuery.padding.bottom + 160)
const _kAccentBorder = 3.0;    // disclaimer card left accent border width

class CreateBidScreen extends StatefulWidget {
  final AnnouncementModel announcement;

  const CreateBidScreen({super.key, required this.announcement});

  @override
  State<CreateBidScreen> createState() => _CreateBidScreenState();
}

class _CreateBidScreenState extends State<CreateBidScreen> {
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  final _recipientSection = RecipientSectionController();

  // ValueNotifiers replace setState for reactive UI — no setState needed
  late final ValueNotifier<double> _weightNotifier;
  final _categoriesNotifier = ValueNotifier<Set<String>>({});
  final _disclaimerNotifier = ValueNotifier<bool>(false);
  // null = pas de quote calculé ; non-null = quote appliqué (promo ou non)
  final _quoteNotifier = ValueNotifier<Object?>(null); // BidQuoteResponse | String (erreur)

  // Catalogue de types de contenu — seedé synchrone avec le catalogue
  // embarqué (fallbackCatalog), puis remplacé par le catalogue live du
  // repository dès qu'il répond (repli automatique hors ligne intégré).
  final _catalogLabelsNotifier = ValueNotifier<List<String>>(
    fallbackCatalog.map((c) => c.label).toList(),
  );
  final _customCatCtrl = TextEditingController();

  double get _maxKg => widget.announcement.availableKg;
  double get _pricePerKg => widget.announcement.pricePerKg;

  Future<void> _loadCatalog() async {
    final categories =
        await getIt<IContentCategoryRepository>().getCategories();
    if (!mounted) return;
    _catalogLabelsNotifier.value = categories.map((c) => c.label).toList();
  }

  void _addCustomCategory() {
    final value = _customCatCtrl.text.trim();
    if (value.isEmpty) return;
    final updated = Set<String>.from(_categoriesNotifier.value)..add(value);
    _categoriesNotifier.value = updated;
    _customCatCtrl.clear();
  }

  void _applyPromoCode() {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) {
      _quoteNotifier.value = null;
      return;
    }
    context.read<BidBloc>().add(BidQuoteRequested(
      announcementId: widget.announcement.id,
      weightKg: _weightNotifier.value,
      promoCode: code,
    ));
  }

  @override
  void initState() {
    super.initState();
    _weightNotifier = ValueNotifier<double>(
      widget.announcement.availableKg >= 5 ? 5 : widget.announcement.availableKg,
    );
    unawaited(_loadCatalog());
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _promoCtrl.dispose();
    _customCatCtrl.dispose();
    _weightNotifier.dispose();
    _categoriesNotifier.dispose();
    _catalogLabelsNotifier.dispose();
    _disclaimerNotifier.dispose();
    _quoteNotifier.dispose();
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
    DonySnackbar.show(context,
        message: message, type: DonySnackbarType.error);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BidBloc, BidState>(
          listener: (context, state) {
            if (state is BidCheckoutReady) {
              _recipientSection.maybeSaveManualEntry();
              context.read<PaymentBloc>().add(BidCheckoutPaymentRequested(
                clientSecret: state.response.clientSecret,
                publishableKey: state.response.publishableKey,
                bidId: state.response.bidId,
              ));
            } else if (state is BidQuoteLoaded) {
              _quoteNotifier.value = state.quote;
            } else if (state is BidPromoError) {
              _quoteNotifier.value = state.error.message;
              ErrorPresenter.show(context, state.error);
            } else if (state is BidError) {
              ErrorPresenter.show(context, state.error);
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
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: _buildAppBar(context),
              body: ListenableBuilder(
                listenable: Listenable.merge([
                  _weightNotifier,
                  _categoriesNotifier,
                  _catalogLabelsNotifier,
                  _disclaimerNotifier,
                ]),
                builder: (context, _) {
                  final weightKg = _weightNotifier.value;
                  final categories = _categoriesNotifier.value;
                  final catalogLabels = _catalogLabelsNotifier.value;
                  final customCategories = categories
                      .where((c) => !catalogLabels.contains(c))
                      .toList();
                  final disclaimerAccepted = _disclaimerNotifier.value;
                  final serviceFee = (weightKg * _pricePerKg) * donyCommissionRate;
                  final basePrice = weightKg * _pricePerKg;
                  final totalPrice = basePrice + serviceFee;
                  final canSubmit =
                      weightKg > 0 && categories.isNotEmpty && disclaimerAccepted;

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          DonyLayout.hPadding(context),
                          DonySpacing.xl,
                          DonyLayout.hPadding(context),
                          DonySpacing.xl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── SECTION: Poids estimé ─────────────────────────────
                            _SectionLabel(label: 'POIDS ESTIMÉ'),
                            const SizedBox(height: DonySpacing.sm),
                            _WeightSection(
                              weightKg: weightKg,
                              maxKg: _maxKg,
                              onChanged: (v) => _weightNotifier.value = v,
                            ).animate().fadeIn(duration: 250.ms),
                            const SizedBox(height: DonySpacing.xxl),

                            // ── SECTION: Contenu du colis ─────────────────────────
                            _SectionLabel(label: 'CONTENU DU COLIS'),
                            const SizedBox(height: DonySpacing.md),
                            Wrap(
                              spacing: DonySpacing.sm,
                              runSpacing: DonySpacing.sm,
                              children: [
                                for (final cat in catalogLabels)
                                  _CategoryChip(
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
                                  ),
                                for (final cat in customCategories)
                                  _CategoryChip(
                                    label: cat,
                                    selected: true,
                                    onTap: () {
                                      final updated = Set<String>.from(categories)
                                        ..remove(cat);
                                      _categoriesNotifier.value = updated;
                                    },
                                  ),
                              ],
                            ).animate().fadeIn(delay: 60.ms),
                            const SizedBox(height: DonySpacing.xxl),

                            // ── SECTION: Description ──────────────────────────────
                            _SectionLabel(label: 'DESCRIPTION (AU VOYAGEUR)'),
                            const SizedBox(height: DonySpacing.sm),
                            DonyTextField(
                              controller: _descCtrl,
                              hint:
                                  'Médicaments pour diabète + 2 tee-shirts enfants',
                            ).animate().fadeIn(delay: 100.ms),
                            const SizedBox(height: DonySpacing.xxl),

                            // ── Valeur déclarée ───────────────────────────────────
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
                                    ?.copyWith(color: cs.onSurfaceVariant),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: DonySpacing.base,
                                  vertical: DonySpacing.md,
                                ),
                              ),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ).animate().fadeIn(delay: 140.ms),
                            const SizedBox(height: DonySpacing.xxl),

                            // ── Destinataire ──────────────────────────────────────
                            _SectionLabel(label: 'DESTINATAIRE'),
                            const SizedBox(height: DonySpacing.md),
                            RecipientSection(
                              controller: _recipientSection,
                              nameCtrl: _recipientNameCtrl,
                              phoneCtrl: _recipientPhoneCtrl,
                              fallbackCity: widget.announcement.arrivalCity,
                              fallbackCountry:
                                  widget.announcement.arrivalCountryCode,
                              children: [
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
                              ],
                            ),
                            const SizedBox(height: DonySpacing.xxl),

                            // ── Autre type de contenu (saisie libre) ──────────────
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const Key('custom-category-input'),
                                    controller: _customCatCtrl,
                                    onSubmitted: (_) => _addCustomCategory(),
                                    decoration: const InputDecoration(
                                      labelText: 'Ajouter un autre type…',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: const Key('add-custom-category-btn'),
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed: _addCustomCategory,
                                  tooltip: 'Ajouter',
                                ),
                              ],
                            ),
                            const SizedBox(height: DonySpacing.xxl),

                            // ── Disclaimer card ───────────────────────────────────
                            _DisclaimerCard(
                              accepted: disclaimerAccepted,
                              onChanged: (v) => _disclaimerNotifier.value = v,
                            ).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: DonySpacing.xxl),

                            // ── Code promo ────────────────────────────────────────
                            _SectionLabel(label: 'CODE PROMO (OPTIONNEL)'),
                            const SizedBox(height: DonySpacing.sm),
                            ValueListenableBuilder<Object?>(
                              valueListenable: _quoteNotifier,
                              builder: (_, quoteVal, __) {
                                final isQuoteLoading = bidState is BidQuoteLoading;
                                final quote = quoteVal is BidQuoteResponse ? quoteVal : null;
                                final promoError = quoteVal is String ? quoteVal : null;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _promoCtrl,
                                            textCapitalization: TextCapitalization.characters,
                                            decoration: InputDecoration(
                                              hintText: 'Ex: WELCOME10',
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: DonySpacing.base,
                                                vertical: DonySpacing.md,
                                              ),
                                              suffixIcon: isQuoteLoading
                                                  ? const Padding(
                                                      padding: EdgeInsets.all(12),
                                                      child: SizedBox(
                                                        width: 20, height: 20,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            onFieldSubmitted: (_) => _applyPromoCode(),
                                          ),
                                        ),
                                        const SizedBox(width: DonySpacing.sm),
                                        SizedBox(
                                          height: 52,
                                          width: 110,
                                          child: FilledButton(
                                            onPressed: isQuoteLoading ? null : _applyPromoCode,
                                            child: const Text('Appliquer'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (quote != null && quote.promoApplied) ...[
                                      const SizedBox(height: DonySpacing.xs),
                                      Row(
                                        children: [
                                          const DonyIcon('circle-check',
                                              size: 16, color: Color(0xFF16A34A)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              quote.promoLabel ?? 'Code appliqué',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: const Color(0xFF16A34A),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (promoError != null) ...[
                                      const SizedBox(height: DonySpacing.xs),
                                      Row(
                                        children: [
                                          const DonyIcon('circle-alert',
                                              size: 16, color: Color(0xFFE53935)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              promoError,
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: const Color(0xFFE53935),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ).animate().fadeIn(delay: 220.ms),
                          ],
                        ),
                      ),
                      ),
                      ValueListenableBuilder<Object?>(
                        valueListenable: _quoteNotifier,
                        builder: (_, quoteVal, __) {
                          final quote = quoteVal is BidQuoteResponse ? quoteVal : null;
                          final effectiveServiceFee = quote != null
                              ? quote.commissionEur
                              : serviceFee;
                          final effectiveTotal = quote != null
                              ? quote.totalEur
                              : totalPrice;
                          return _BottomBar(
                            weightKg: weightKg,
                            pricePerKg: _pricePerKg,
                            basePrice: basePrice,
                            serviceFee: effectiveServiceFee,
                            totalPrice: effectiveTotal,
                            isLoading: isLoading,
                            canSubmit: canSubmit,
                            onSubmit: _submit,
                            promoApplied: quote?.promoApplied ?? false,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            );
        },
      ),
    );
  }

  Future<void> _presentPaymentSheet(
    BuildContext context,
    CheckoutPaymentSheetReady state,
  ) async {
    final authenticated = await requirePaymentAuth(
      context,
      authService: getIt<LocalAuthService>(),
      userPrefs: getIt<HiveService>().userPrefs,
    );
    if (!context.mounted) return;
    if (!authenticated) {
      _showError('Authentification requise pour effectuer le paiement');
      return;
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: donyPaymentSheetParams(state.clientSecret),
      );

      await Stripe.instance.presentPaymentSheet();

      if (!context.mounted) return;
      // Synchronously confirm the payment with the backend so the bid is
      // promoted to PENDING immediately (does not depend on the Stripe webhook).
      context
          .read<BidBloc>()
          .add(BidConfirmPaymentRequested(state.bidId));
      // ?from=payment makes the bid-detail back arrow route to /home (mes envois)
      // instead of popping back to the just-completed checkout form.
      context.push('/bids/${state.bidId}?from=payment');
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final travelerName =
        widget.announcement.traveler?.resolvedName ?? 'Voyageur';
    final depDate = DateFormat('d MMM', 'fr')
        .format(widget.announcement.departureDate);

    return AppBar(
      backgroundColor: DonyColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        tooltip: 'Fermer',
        onPressed: () => context.pop(),
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
          ),
          child: DonyIcon('x', size: 20, color: cs.primary),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Demande d'envoi", style: tt.headlineLarge),
          Text(
            'Avec $travelerName · $depDate',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: cs.outline),
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Large weight display
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              weightKg.toStringAsFixed(0),
              style: tt.displayLarge
                  ?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(width: DonySpacing.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm),
              child: Text(
                'kg',
                style: tt.headlineMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const Spacer(),
            Text(
              'max ${maxKg.toStringAsFixed(0)} kg',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.outline,
            thumbColor: cs.primary,
            overlayColor: cs.primary.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
            ),
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
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '${maxKg.toStringAsFixed(0)} kg',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? cs.onSurface : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(
            color: selected ? cs.onSurface : cs.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              DonyIcon('check',
                  size: 14, color: cs.surface),
              const SizedBox(width: DonySpacing.xxs),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: selected ? cs.surface : cs.onSurface,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(DonyRadius.card)),
        border: Border(
          left: BorderSide(color: cs.secondary, width: _kAccentBorder),
        ),
      ),
      padding: const EdgeInsets.all(DonySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIcon(
                'triangle-alert',
                size: 20,
                color: cs.secondary,
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disclaimer douane.',
                      style: tt.titleMedium
                          ?.copyWith(color: cs.onSecondaryContainer),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      'Pas d\'armes, drogues, liquides inflammables ou espèces. '
                      'Le voyageur peut refuser au contrôle douanier.',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSecondaryContainer, height: 1.5),
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
                  activeColor: cs.secondary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    'Je signe & j\'accepte',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface,
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

// ── Bottom bar with price breakdown + CTA ────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.weightKg,
    required this.pricePerKg,
    required this.basePrice,
    required this.serviceFee,
    required this.totalPrice,
    required this.isLoading,
    required this.canSubmit,
    required this.onSubmit,
    this.promoApplied = false,
  });

  final double weightKg;
  final double pricePerKg;
  final double basePrice;
  final double serviceFee;
  final double totalPrice;
  final bool isLoading;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final bool promoApplied;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Container(
      padding: EdgeInsets.fromLTRB(
        DonyLayout.hPadding(context),
        DonySpacing.base,
        DonyLayout.hPadding(context),
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Price rows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${weightKg.toStringAsFixed(0)} kg × '
                '${pricePerKg.toStringAsFixed(0)}€',
                style: tt.bodyMedium,
              ),
              Text(
                fmt.format(basePrice),
                style: tt.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Frais de service',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (promoApplied) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tarif préférentiel',
                        style: tt.labelSmall?.copyWith(
                          color: const Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                fmt.format(serviceFee),
                style: tt.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Divider(color: cs.outline),
          const SizedBox(height: DonySpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: tt.titleLarge),
              Text(
                fmt.format(totalPrice),
                style: tt.titleLarge
                    ?.copyWith(color: cs.primary),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          // CTA
          DonyButton(
            label:
                'Bloquer ${fmt.format(totalPrice)} & envoyer',
            onPressed: canSubmit && !isLoading ? onSubmit : null,
            isLoading: isLoading,
            iconAsset: 'lock',
          ),
        ],
      ),
    );
  }
}
