import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/grid_item_selection_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
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
    VoidCallback? submit;
    final canSubmitNotifier = ValueNotifier<bool>(false);
    final totalPriceNotifier = ValueNotifier<double>(
      announcement.availableKg >= 5
          ? 5 * announcement.pricePerKg * 1.12
          : announcement.availableKg * announcement.pricePerKg * 1.12,
    );
    final paymentMethodNotifier =
        ValueNotifier<BidPaymentMethod>(BidPaymentMethod.stripe);
    final isCashAvailable =
        announcement.acceptedPaymentMethods.contains(BidPaymentMethod.cash);
    final isWaveAvailable =
        announcement.acceptedPaymentMethods.contains(BidPaymentMethod.wave);
    final isOrangeMoneyAvailable =
        announcement.acceptedPaymentMethods.contains(BidPaymentMethod.orangeMoney);

    // BLoCs créés explicitement pour partage cohérent child ↔ stickyBottom.
    final bidBloc = getIt<BidBloc>();
    final paymentBloc = getIt<PaymentBloc>();
    return DonyBottomSheet.show(
      context,
      title: 'Envoyer un colis',
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<PaymentBloc>.value(value: paymentBloc),
        ],
        child: child,
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmitNotifier,
        builder: (ctx, canSubmit, _) =>
            ValueListenableBuilder<BidPaymentMethod>(
          valueListenable: paymentMethodNotifier,
          builder: (ctx, method, _) =>
              ValueListenableBuilder<double>(
            valueListenable: totalPriceNotifier,
            builder: (ctx, totalPrice, _) =>
                BlocBuilder<BidBloc, BidState>(
              bloc: bidBloc,
              builder: (ctx, state) {
                final isLoading = state is BidLoading;
                final isCash = method == BidPaymentMethod.cash;
                final isMobileMoney = method == BidPaymentMethod.wave ||
                    method == BidPaymentMethod.orangeMoney;
                final String btnLabel;
                final IconData btnIcon;
                if (isCash) {
                  btnLabel = 'Envoyer (paiement en espèces)';
                  btnIcon = Icons.payments_rounded;
                } else if (isMobileMoney) {
                  btnLabel = 'Envoyer (Mobile Money)';
                  btnIcon = Icons.phone_android_rounded;
                } else {
                  btnLabel = 'Bloquer ${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(totalPrice)} & envoyer';
                  btnIcon = Icons.lock_rounded;
                }
                return DonyButton(
                  label: btnLabel,
                  isLoading: isLoading,
                  onPressed:
                      (canSubmit && !isLoading) ? () => submit?.call() : null,
                  icon: btnIcon,
                );
              },
            ),
          ),
        ),
      ),
      child: _CreateBidContent(
        announcement: announcement,
        canSubmitNotifier: canSubmitNotifier,
        totalPriceNotifier: totalPriceNotifier,
        paymentMethodNotifier: paymentMethodNotifier,
        isCashAvailable: isCashAvailable,
        isWaveAvailable: isWaveAvailable,
        isOrangeMoneyAvailable: isOrangeMoneyAvailable,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(() {
      canSubmitNotifier.dispose();
      totalPriceNotifier.dispose();
      paymentMethodNotifier.dispose();
      bidBloc.close();
      paymentBloc.close();
    });
  }
}

// ─── Content widget ───────────────────────────────────────────────────────────

class _CreateBidContent extends StatefulWidget {
  const _CreateBidContent({
    required this.announcement,
    this.canSubmitNotifier,
    this.totalPriceNotifier,
    this.paymentMethodNotifier,
    this.isCashAvailable = false,
    this.isWaveAvailable = false,
    this.isOrangeMoneyAvailable = false,
    this.onSubmitReady,
  });

  final AnnouncementModel announcement;
  final ValueNotifier<bool>? canSubmitNotifier;
  final ValueNotifier<double>? totalPriceNotifier;
  final ValueNotifier<BidPaymentMethod>? paymentMethodNotifier;
  final bool isCashAvailable;
  final bool isWaveAvailable;
  final bool isOrangeMoneyAvailable;
  final void Function(VoidCallback)? onSubmitReady;

  @override
  State<_CreateBidContent> createState() => _CreateBidContentState();
}

// Pays Mobile Money disponibles (code ISO → libellé)
const _mmCountries = {
  'CI': 'Côte d\'Ivoire',
  'SN': 'Sénégal',
  'ML': 'Mali',
  'GN': 'Guinée',
  'BF': 'Burkina Faso',
  'CM': 'Cameroun',
};

class _CreateBidContentState extends State<_CreateBidContent> {
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  // Mobile Money fields
  final _mmPhoneCtrl = TextEditingController();
  final _mmCountryNotifier = ValueNotifier<String?>('CI');

  // ValueNotifiers replace setState for reactive UI — no setState needed
  late final ValueNotifier<double> _weightNotifier;
  final _categoriesNotifier = ValueNotifier<Set<String>>({});
  final _disclaimerNotifier = ValueNotifier<bool>(false);
  // Local copy of payment method so the widget doesn't hold a reference to
  // the external notifier that may be disposed during the sheet exit animation.
  late final ValueNotifier<BidPaymentMethod> _methodNotifier;
  // Grid quantities for MIXED pricing mode (itemId → quantity).
  final _gridQuantitiesNotifier = ValueNotifier<Map<String, int>>({});

  double get _maxKg => widget.announcement.availableKg;
  double get _pricePerKg => widget.announcement.pricePerKg;

  @override
  void initState() {
    super.initState();
    final hasKgPricing = widget.announcement.pricePerKg > 0;
    _weightNotifier = ValueNotifier<double>(
      hasKgPricing
          ? (widget.announcement.availableKg >= 5
              ? 5
              : widget.announcement.availableKg)
          : 0.0,
    );
    _methodNotifier = ValueNotifier<BidPaymentMethod>(
      widget.paymentMethodNotifier?.value ?? BidPaymentMethod.stripe,
    );
    // Mirror external notifier changes into the local copy.
    widget.paymentMethodNotifier?.addListener(_syncMethodFromExternal);
    widget.onSubmitReady?.call(_submit);
    _weightNotifier.addListener(_syncStickyState);
    _categoriesNotifier.addListener(_syncStickyState);
    _disclaimerNotifier.addListener(_syncStickyState);
    _gridQuantitiesNotifier.addListener(_syncStickyState);
    _methodNotifier.addListener(_syncMethodToExternal);
    _methodNotifier.addListener(_syncStickyState);
    _mmPhoneCtrl.addListener(_syncStickyState);
    _mmCountryNotifier.addListener(_syncStickyState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncStickyState());
  }

  void _syncMethodFromExternal() {
    final ext = widget.paymentMethodNotifier?.value;
    if (ext != null && ext != _methodNotifier.value) {
      _methodNotifier.value = ext;
    }
  }

  void _syncMethodToExternal() {
    final ext = widget.paymentMethodNotifier;
    if (ext != null && ext.value != _methodNotifier.value) {
      ext.value = _methodNotifier.value;
    }
  }

  bool get _isMobileMoneySelected {
    final m = _methodNotifier.value;
    return m == BidPaymentMethod.wave || m == BidPaymentMethod.orangeMoney;
  }

  void _syncStickyState() {
    final weightKg = _weightNotifier.value;
    final categories = _categoriesNotifier.value;
    final disclaimerAccepted = _disclaimerNotifier.value;
    final hasGridPricing = widget.announcement.priceGridItems.isNotEmpty;
    final hasKgPricing = widget.announcement.pricePerKg > 0;
    final gridQuantities = _gridQuantitiesNotifier.value;
    final hasGridItems = hasGridPricing && gridQuantities.isNotEmpty;
    final hasWeight = hasKgPricing && weightKg > 0;
    // If Mobile Money is selected, phone must be filled in.
    final mmOk = !_isMobileMoneySelected ||
        (_mmPhoneCtrl.text.trim().isNotEmpty &&
            _mmCountryNotifier.value != null);
    final canSubmit =
        (hasGridItems || hasWeight) && categories.isNotEmpty && disclaimerAccepted && mmOk;

    final weightTotal = hasKgPricing ? weightKg * widget.announcement.pricePerKg * 1.12 : 0.0;
    final gridTotal = hasGridPricing
        ? widget.announcement.priceGridItems.fold<double>(
            0.0,
            (sum, item) =>
                sum + item.unitPriceDisplay * (gridQuantities[item.id] ?? 0),
          )
        : 0.0;

    final totalPrice = weightTotal + gridTotal;
    widget.canSubmitNotifier?.value = canSubmit;
    widget.totalPriceNotifier?.value = totalPrice;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _mmPhoneCtrl.dispose();
    widget.paymentMethodNotifier?.removeListener(_syncMethodFromExternal);
    _weightNotifier.removeListener(_syncStickyState);
    _categoriesNotifier.removeListener(_syncStickyState);
    _disclaimerNotifier.removeListener(_syncStickyState);
    _gridQuantitiesNotifier.removeListener(_syncStickyState);
    _methodNotifier.removeListener(_syncMethodToExternal);
    _methodNotifier.removeListener(_syncStickyState);
    _mmPhoneCtrl.removeListener(_syncStickyState);
    _mmCountryNotifier.removeListener(_syncStickyState);
    _weightNotifier.dispose();
    _categoriesNotifier.dispose();
    _disclaimerNotifier.dispose();
    _methodNotifier.dispose();
    _gridQuantitiesNotifier.dispose();
    _mmCountryNotifier.dispose();
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

    // Build grid items payload for MIXED pricing mode.
    final gridItems = widget.announcement.priceGridItems
        .where((item) =>
            (_gridQuantitiesNotifier.value[item.id] ?? 0) > 0)
        .map((item) => {
              'announcementGridItemId': item.id,
              'quantity': _gridQuantitiesNotifier.value[item.id]!,
            })
        .toList();

    final method = _methodNotifier.value;
    final isMobileMoney = method == BidPaymentMethod.wave ||
        method == BidPaymentMethod.orangeMoney;

    if (isMobileMoney) {
      final mmPhone = _mmPhoneCtrl.text.trim();
      if (mmPhone.isEmpty) {
        _showError('Numéro Mobile Money obligatoire');
        return;
      }
      if (_mmCountryNotifier.value == null) {
        _showError('Pays Mobile Money obligatoire');
        return;
      }
      context.read<BidBloc>().add(BidCreateRequested(
        announcementId: widget.announcement.id,
        weightKg: _weightNotifier.value,
        declaredValueEur: val,
        description: _descCtrl.text.trim(),
        contentCategory: _categoriesNotifier.value.join(', '),
        recipientName: _recipientNameCtrl.text.trim(),
        recipientPhone: _recipientPhoneCtrl.text.trim(),
        paymentMethod: method,
        phoneNumber: mmPhone,
        countryCode: _mmCountryNotifier.value,
        gridItems: gridItems.isEmpty ? null : gridItems,
      ));
    } else if (method == BidPaymentMethod.cash) {
      context.read<BidBloc>().add(BidCreateRequested(
        announcementId: widget.announcement.id,
        weightKg: _weightNotifier.value,
        declaredValueEur: val,
        description: _descCtrl.text.trim(),
        contentCategory: _categoriesNotifier.value.join(', '),
        recipientName: _recipientNameCtrl.text.trim(),
        recipientPhone: _recipientPhoneCtrl.text.trim(),
        paymentMethod: BidPaymentMethod.cash,
        gridItems: gridItems.isEmpty ? null : gridItems,
      ));
    } else {
      context.read<BidBloc>().add(BidCheckoutRequested(
        announcementId: widget.announcement.id,
        weightKg: _weightNotifier.value,
        declaredValueEur: val,
        description: _descCtrl.text.trim(),
        contentCategory: _categoriesNotifier.value.join(', '),
        recipientName: _recipientNameCtrl.text.trim(),
        recipientPhone: _recipientPhoneCtrl.text.trim(),
        gridItems: gridItems.isEmpty ? null : gridItems,
      ));
    }
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
            if (state is BidCreated) {
              Navigator.of(context, rootNavigator: true).pop();
              if (context.mounted) {
                unawaited(context.push('/bids/${state.bid.id}?from=payment'));
              }
            } else if (state is BidCheckoutReady) {
              context.read<PaymentBloc>().add(BidCheckoutPaymentRequested(
                clientSecret: state.response.clientSecret,
                publishableKey: state.response.publishableKey,
                bidId: state.response.bidId,
              ));
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
          return ListenableBuilder(
            listenable: Listenable.merge([
              _weightNotifier,
              _categoriesNotifier,
              _disclaimerNotifier,
              _methodNotifier,
              _gridQuantitiesNotifier,
            ]),
            builder: (context, _) {
              final weightKg = _weightNotifier.value;
              final categories = _categoriesNotifier.value;
              final disclaimerAccepted = _disclaimerNotifier.value;
              final currentMethod = _methodNotifier.value;
              final gridQuantities = _gridQuantitiesNotifier.value;
              final hasGridPricing = widget.announcement.priceGridItems.isNotEmpty;
              final hasKgPricing = widget.announcement.pricePerKg > 0;
              final serviceFee = weightKg * _pricePerKg * 0.12;
              final basePrice = weightKg * _pricePerKg;
              final totalPrice = basePrice + serviceFee;

              // Grid total (articles only, displayed as informational recap).
              final gridTotal = hasGridPricing
                  ? widget.announcement.priceGridItems.fold<double>(
                      0,
                      (sum, item) =>
                          sum +
                          item.unitPriceDisplay *
                              (gridQuantities[item.id] ?? 0),
                    )
                  : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SECTION: Articles de la grille ─────────────────────
                  if (hasGridPricing) ...[
                    const _SectionLabel(label: 'ARTICLES'),
                    const SizedBox(height: DonySpacing.sm),
                    ValueListenableBuilder<Map<String, int>>(
                      valueListenable: _gridQuantitiesNotifier,
                      builder: (context, quantities, _) {
                        final totalSelected = quantities.values
                            .fold<int>(0, (s, q) => s + q);
                        final subtotal = widget.announcement.priceGridItems
                            .fold<double>(
                          0.0,
                          (s, item) =>
                              s +
                              item.unitPriceDisplay *
                                  (quantities[item.id] ?? 0),
                        );
                        final hasSelection = quantities.isNotEmpty;

                        return GestureDetector(
                          onTap: () async {
                            final result = await GridItemSelectionSheet.show(
                              context,
                              items: widget.announcement.priceGridItems,
                              initialQuantities: quantities,
                              corridor:
                                  '${widget.announcement.departureCity} → ${widget.announcement.arrivalCity}',
                            );
                            if (result != null) {
                              _gridQuantitiesNotifier.value = result;
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: double.infinity,
                            padding: const EdgeInsets.all(DonySpacing.base),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius:
                                  BorderRadius.circular(DonyRadius.card),
                              border: hasSelection
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .success,
                                      width: 1.5,
                                    )
                                  : Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .warning,
                                      width: 1.5,
                                    ),
                            ),
                            child: hasSelection
                                ? Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .success,
                                        size: 18,
                                      ),
                                      const SizedBox(width: DonySpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$totalSelected article${totalSelected > 1 ? 's' : ''} sélectionné${totalSelected > 1 ? 's' : ''}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              'Sous-total : ${subtotal.toStringAsFixed(2)} €',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .success,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'Modifier',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .warning,
                                        size: 18,
                                      ),
                                      const SizedBox(width: DonySpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Choisir mes articles',
                                              key: const Key(
                                                  'choose-articles-btn'),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              'Requis — au moins 1 article',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: DonySpacing.xxl),
                  ],

                  // ── SECTION: Poids estimé (masqué si pas de tarif kg) ──
                  if (hasKgPricing) ...[
                    _WeightSection(
                      weightKg: weightKg,
                      maxKg: _maxKg,
                      isMixed: hasGridPricing,
                      onChanged: (v) => _weightNotifier.value = v,
                    ).animate().fadeIn(duration: 250.ms),
                    const SizedBox(height: DonySpacing.xxl),
                  ],

                  // ── SECTION: Contenu du colis ───────────────────────────
                  const _SectionLabel(label: 'CONTENU DU COLIS'),
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
                  const _SectionLabel(label: 'DESCRIPTION (AU VOYAGEUR)'),
                  const SizedBox(height: DonySpacing.sm),
                  DonyTextField(
                    controller: _descCtrl,
                    hint: 'Médicaments pour diabète + 2 tee-shirts enfants',
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // ── Valeur déclarée ─────────────────────────────────────
                  const _SectionLabel(label: 'VALEUR DÉCLARÉE (€)'),
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
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.md,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ).animate().fadeIn(delay: 140.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // ── Destinataire ────────────────────────────────────────
                  const _SectionLabel(label: 'DESTINATAIRE'),
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

                  // ── SECTION: Mode de paiement ────────────────────────────
                  if (widget.isCashAvailable ||
                      widget.isWaveAvailable ||
                      widget.isOrangeMoneyAvailable) ...[
                    const _SectionLabel(label: 'MODE DE PAIEMENT'),
                    const SizedBox(height: DonySpacing.md),
                    _PaymentMethodSelector(
                      selectedMethod: currentMethod,
                      onChanged: (m) => _methodNotifier.value = m,
                      isCashAvailable: widget.isCashAvailable,
                      isWaveAvailable: widget.isWaveAvailable,
                      isOrangeMoneyAvailable: widget.isOrangeMoneyAvailable,
                    ).animate().fadeIn(delay: 190.ms),
                    const SizedBox(height: DonySpacing.xxl),
                  ],

                  // ── SECTION: Mobile Money — numéro + pays ─────────────────
                  if (_isMobileMoneySelected) ...[
                    const _SectionLabel(label: 'NUMÉRO MOBILE MONEY'),
                    const SizedBox(height: DonySpacing.sm),
                    DonyTextField(
                      controller: _mmPhoneCtrl,
                      label: 'Numéro de téléphone Mobile Money',
                      hint: 'ex: +221 77 000 00 00',
                      keyboardType: TextInputType.phone,
                    ).animate().fadeIn(duration: 200.ms),
                    const SizedBox(height: DonySpacing.md),
                    ValueListenableBuilder<String?>(
                      valueListenable: _mmCountryNotifier,
                      builder: (context, selectedCountry, _) {
                        return DropdownButtonFormField<String>(
                          value: selectedCountry,
                          decoration: InputDecoration(
                            labelText: 'Pays Mobile Money',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: DonySpacing.base,
                              vertical: DonySpacing.md,
                            ),
                          ),
                          items: _mmCountries.entries
                              .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ))
                              .toList(),
                          onChanged: (v) => _mmCountryNotifier.value = v,
                        );
                      },
                    ).animate().fadeIn(delay: 40.ms),
                    const SizedBox(height: DonySpacing.xxl),
                  ],

                  // ── Disclaimer card ─────────────────────────────────────
                  _DisclaimerCard(
                    accepted: disclaimerAccepted,
                    onChanged: (v) => _disclaimerNotifier.value = v,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // ── Récap articles grille (si articles sélectionnés) ─
                  if (hasGridPricing && gridTotal > 0) ...[
                    _GridTotalRecap(gridTotal: gridTotal),
                    const SizedBox(height: DonySpacing.md),
                  ],

                  // ── Price breakdown (KG mode uniquement) ────────────────
                  if (hasKgPricing)
                    _PriceBreakdown(
                      weightKg: weightKg,
                      pricePerKg: _pricePerKg,
                      basePrice: basePrice,
                      serviceFee: serviceFee,
                      totalPrice: totalPrice,
                    ),
                  const SizedBox(height: DonySpacing.md),
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
    this.isMixed = false,
  });

  final double weightKg;
  final double maxKg;
  final ValueChanged<double> onChanged;
  /// En mode MIXED, le poids est optionnel : min slider = 0.
  final bool isMixed;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sliderMin = isMixed ? 0.0 : 1.0;

    // Guard: if maxKg <= sliderMin the slider range is invalid (Flutter requires
    // min < max). Show a graceful "no capacity" message instead of crashing.
    if (maxKg <= sliderMin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMixed ? 'Poids du colis (optionnel)' : 'Poids du colis',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Aucune capacité disponible',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    final divisions = (maxKg - sliderMin).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label with optional indicator
        Row(
          children: [
            Text(
              isMixed ? 'Poids du colis (optionnel)' : 'Poids du colis',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        // Large weight display
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              weightKg.toStringAsFixed(0),
              style: tt.displayLarge?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(width: DonySpacing.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm),
              child: Text(
                'kg',
                style: tt.headlineMedium?.copyWith(color: cs.onSurfaceVariant),
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
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: weightKg,
            min: sliderMin,
            max: maxKg,
            divisions: divisions > 0 ? divisions : null,
            onChanged: onChanged,
          ),
        ),
        // Range labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isMixed ? '0 kg' : '1 kg',
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
              Icon(Icons.check_rounded, size: 14, color: cs.surface),
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
              Icon(
                Icons.warning_amber_rounded,
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
                      style: tt.titleMedium?.copyWith(color: cs.onSecondaryContainer),
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

// ── Payment method selector ───────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selectedMethod,
    required this.onChanged,
    this.isCashAvailable = false,
    this.isWaveAvailable = false,
    this.isOrangeMoneyAvailable = false,
  });

  final BidPaymentMethod selectedMethod;
  final ValueChanged<BidPaymentMethod> onChanged;
  final bool isCashAvailable;
  final bool isWaveAvailable;
  final bool isOrangeMoneyAvailable;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      Expanded(
        child: _MethodTile(
          key: const Key('payment-method-stripe'),
          icon: Icons.lock_rounded,
          label: 'Paiement sécurisé',
          sublabel: 'Via Stripe',
          selected: selectedMethod == BidPaymentMethod.stripe,
          onTap: () => onChanged(BidPaymentMethod.stripe),
        ),
      ),
      if (isCashAvailable) ...[
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: _MethodTile(
            key: const Key('payment-method-cash'),
            icon: Icons.payments_rounded,
            label: 'En espèces',
            sublabel: 'Remise directe',
            selected: selectedMethod == BidPaymentMethod.cash,
            onTap: () => onChanged(BidPaymentMethod.cash),
          ),
        ),
      ],
      if (isWaveAvailable) ...[
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: _MethodTile(
            key: const Key('payment-method-wave'),
            icon: Icons.waves_rounded,
            label: 'Wave',
            sublabel: 'Mobile Money',
            selected: selectedMethod == BidPaymentMethod.wave,
            onTap: () => onChanged(BidPaymentMethod.wave),
          ),
        ),
      ],
      if (isOrangeMoneyAvailable) ...[
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: _MethodTile(
            key: const Key('payment-method-orange-money'),
            icon: Icons.phone_android_rounded,
            label: 'Orange Money',
            sublabel: 'Mobile Money',
            selected: selectedMethod == BidPaymentMethod.orangeMoney,
            onTap: () => onChanged(BidPaymentMethod.orangeMoney),
          ),
        ),
      ],
    ];

    // If more than 2 payment method tiles (Expanded), wrap for better layout on small screens.
    final expandedCount = tiles.whereType<Expanded>().length;
    if (expandedCount > 2) {
      return Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: tiles
            .whereType<Expanded>()
            .map((e) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 60) / 2,
                  child: e.child,
                ))
            .toList(),
      );
    }

    return Row(children: tiles);
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    super.key,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? cs.primary : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: selected ? cs.onPrimaryContainer : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              sublabel,
              style: tt.bodySmall?.copyWith(
                color:
                    selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid total recap ─────────────────────────────────────────────────────────

class _GridTotalRecap extends StatelessWidget {
  const _GridTotalRecap({required this.gridTotal});

  final double gridTotal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total articles',
            style: tt.labelMedium?.copyWith(color: cs.onPrimary),
          ),
          Text(
            '${gridTotal.toStringAsFixed(2)} €',
            style: tt.titleSmall?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w800,
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
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
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
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(fmt.format(serviceFee), style: tt.bodyMedium),
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
                style: tt.titleLarge?.copyWith(color: cs.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
