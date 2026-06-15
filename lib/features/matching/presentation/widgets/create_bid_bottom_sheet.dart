import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_quote_response.dart';
import 'package:dony/features/matching/presentation/widgets/grid_item_selection_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
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

const _kAccentBorder = 3.0;

// ── Multi-step helpers ─────────────────────────────────────────────────────────

enum _FormStep { form, paymentPicker }

class _BtnConfig {
  const _BtnConfig({
    required this.label,
    required this.iconAsset,
    this.onPressed,
  });
  final String label;
  final String iconAsset;
  final VoidCallback? onPressed;
}

class _CollectedFormData {
  const _CollectedFormData({
    required this.weightKg,
    required this.declaredValueEur,
    required this.description,
    required this.contentCategory,
    required this.recipientName,
    required this.recipientPhone,
    this.gridItems,
    this.promoCode,
  });
  final double weightKg;
  final double declaredValueEur;
  final String description;
  final String contentCategory;
  final String recipientName;
  final String recipientPhone;
  final List<Map<String, dynamic>>? gridItems;
  final String? promoCode;
}

const _mmCountries = {
  'CI': 'Côte d\'Ivoire',
  'SN': 'Sénégal',
  'ML': 'Mali',
  'GN': 'Guinée',
  'BF': 'Burkina Faso',
  'CM': 'Cameroun',
};

// ── Public API ─────────────────────────────────────────────────────────────────

class CreateBidBottomSheet {
  static Future<void> show(
    BuildContext context, {
    required AnnouncementModel announcement,
  }) {
    final btnConfigNotifier = ValueNotifier<_BtnConfig?>(const _BtnConfig(
      label: 'Envoyer',
      iconAsset: 'send',
    ));
    final isCashAvailable =
        announcement.acceptedPaymentMethods.contains(BidPaymentMethod.cash);
    final isWaveAvailable =
        announcement.acceptedPaymentMethods.contains(BidPaymentMethod.wave);
    final isOrangeMoneyAvailable = announcement.acceptedPaymentMethods
        .contains(BidPaymentMethod.orangeMoney);

    final bidBloc = getIt<BidBloc>();
    final paymentBloc = getIt<PaymentBloc>();

    return DonyBottomSheet.show(
      context,
      title: 'Envoyer un colis',
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<PaymentBloc>.value(value: paymentBloc),
          BlocProvider<WalletBloc>(
            create: (_) => getIt<WalletBloc>()..add(WalletLoadRequested()),
          ),
        ],
        child: child,
      ),
      stickyBottom: ValueListenableBuilder<_BtnConfig?>(
        valueListenable: btnConfigNotifier,
        builder: (ctx, config, _) => BlocBuilder<BidBloc, BidState>(
          bloc: bidBloc,
          builder: (ctx, state) {
            final isLoading = state is BidLoading;
            return DonyButton(
              label: config?.label ?? 'Envoyer',
              iconAsset: config?.iconAsset ?? 'send',
              isLoading: isLoading,
              onPressed: isLoading ? null : config?.onPressed,
            );
          },
        ),
      ),
      child: _CreateBidContent(
        announcement: announcement,
        btnConfigNotifier: btnConfigNotifier,
        isCashAvailable: isCashAvailable,
        isWaveAvailable: isWaveAvailable,
        isOrangeMoneyAvailable: isOrangeMoneyAvailable,
        bidBloc: bidBloc,
        paymentBloc: paymentBloc,
      ),
    ).whenComplete(() {
      btnConfigNotifier.dispose();
      bidBloc.close();
      paymentBloc.close();
      // walletBloc.close() — géré automatiquement par BlocProvider
    });
  }
}

// ── Content widget ─────────────────────────────────────────────────────────────

class _CreateBidContent extends StatefulWidget {
  const _CreateBidContent({
    required this.announcement,
    required this.btnConfigNotifier,
    required this.isCashAvailable,
    required this.isWaveAvailable,
    required this.isOrangeMoneyAvailable,
    required this.bidBloc,
    required this.paymentBloc,
  });

  final AnnouncementModel announcement;
  final ValueNotifier<_BtnConfig?> btnConfigNotifier;
  final bool isCashAvailable;
  final bool isWaveAvailable;
  final bool isOrangeMoneyAvailable;
  final BidBloc bidBloc;
  final PaymentBloc paymentBloc;

  @override
  State<_CreateBidContent> createState() => _CreateBidContentState();
}

class _CreateBidContentState extends State<_CreateBidContent> {
  // ── Form step fields ───────────────────────────────────────────────────────
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  late final ValueNotifier<double> _weightNotifier;
  final _categoriesNotifier = ValueNotifier<Set<String>>({});
  final _disclaimerNotifier = ValueNotifier<bool>(false);
  final _gridQuantitiesNotifier = ValueNotifier<Map<String, int>>({});

  // ── Multi-step state ───────────────────────────────────────────────────────
  final _stepNotifier = ValueNotifier<_FormStep>(_FormStep.form);
  _CollectedFormData? _formData;

  // ── Code promo ─────────────────────────────────────────────────────────────
  final _promoCtrl = TextEditingController();
  // null = pas de devis ; BidQuoteResponse = promo valide ; String = erreur
  final _quoteNotifier = ValueNotifier<Object?>(null);

  // ── Picker step fields ─────────────────────────────────────────────────────
  final _methodNotifier =
      ValueNotifier<BidPaymentMethod>(BidPaymentMethod.stripe);
  final _mmPhoneCtrl = TextEditingController();
  final _mmCountryNotifier = ValueNotifier<String?>('CI');

  double get _maxKg => widget.announcement.availableKg;
  double get _pricePerKg => widget.announcement.pricePerKg;

  /// Articles sélectionnés au format attendu par l'API (`null` si aucun).
  List<Map<String, dynamic>>? _selectedGridItems() {
    final q = _gridQuantitiesNotifier.value;
    final items = <Map<String, dynamic>>[];
    for (final item in widget.announcement.priceGridItems) {
      final qty = q[item.id] ?? 0;
      if (qty > 0) {
        items.add({'announcementGridItemId': item.id, 'quantity': qty});
      }
    }
    return items.isEmpty ? null : items;
  }

  /// Total grille « prix affiché expéditeur » (commission Dony incluse), au taux global.
  double _gridDisplayTotal() {
    final q = _gridQuantitiesNotifier.value;
    return widget.announcement.priceGridItems.fold<double>(
      0,
      (sum, item) => sum + item.unitPriceDisplay * (q[item.id] ?? 0),
    );
  }

  void _applyPromoCode() {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) { _quoteNotifier.value = null; return; }
    final weight = _weightNotifier.value;
    widget.bidBloc.add(BidQuoteRequested(
      announcementId: widget.announcement.id,
      weightKg: weight > 0 ? weight : null,
      promoCode: code,
      gridItems: _selectedGridItems(),
    ));
  }

  /// Un devis (promo) calculé sur d'anciens poids/articles devient caduc.
  void _invalidateQuote() {
    if (_quoteNotifier.value != null) _quoteNotifier.value = null;
  }

  bool get _hasAlternativePaymentMethods =>
      widget.isCashAvailable ||
      widget.isWaveAvailable ||
      widget.isOrangeMoneyAvailable;

  @override
  void initState() {
    super.initState();
    final hasKgPricing = widget.announcement.pricePerKg > 0;
    final cap = _maxKg;
    _weightNotifier = ValueNotifier<double>(
      hasKgPricing
          ? (widget.announcement.isKgFree ? 5.0 : (cap >= 5 ? 5 : cap))
          : 0.0,
    );

    // Form step listeners
    _weightNotifier.addListener(_syncFormButtonState);
    _categoriesNotifier.addListener(_syncFormButtonState);
    _disclaimerNotifier.addListener(_syncFormButtonState);
    _gridQuantitiesNotifier.addListener(_syncFormButtonState);

    // Tout changement de poids/articles invalide un devis promo désormais périmé.
    _weightNotifier.addListener(_invalidateQuote);
    _gridQuantitiesNotifier.addListener(_invalidateQuote);

    // Picker step listeners
    _stepNotifier.addListener(_onStepChanged);
    _methodNotifier.addListener(_syncPickerButtonState);
    _mmPhoneCtrl.addListener(_syncPickerButtonState);
    _mmCountryNotifier.addListener(_syncPickerButtonState);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncFormButtonState());
  }

  // ── Button state sync ──────────────────────────────────────────────────────

  void _onStepChanged() {
    if (_stepNotifier.value == _FormStep.paymentPicker) {
      _syncPickerButtonState();
    } else {
      _syncFormButtonState();
    }
  }

  void _syncFormButtonState() {
    if (_stepNotifier.value != _FormStep.form) return;
    final hasKgPricing = widget.announcement.pricePerKg > 0;
    final hasGridPricing = widget.announcement.priceGridItems.isNotEmpty;
    final weightOk = hasKgPricing && _weightNotifier.value > 0;
    final gridOk =
        hasGridPricing && _gridQuantitiesNotifier.value.isNotEmpty;
    final canSubmit = (weightOk || gridOk) &&
        _categoriesNotifier.value.isNotEmpty &&
        _disclaimerNotifier.value;

    widget.btnConfigNotifier.value = _BtnConfig(
      label: 'Envoyer',
      iconAsset: 'send',
      onPressed: canSubmit ? _goToPicker : null,
    );
  }

  void _syncPickerButtonState() {
    if (_stepNotifier.value != _FormStep.paymentPicker) return;
    final method = _methodNotifier.value;
    final isMM = method == BidPaymentMethod.wave ||
        method == BidPaymentMethod.orangeMoney;
    final mmOk = !isMM ||
        (_mmPhoneCtrl.text.trim().isNotEmpty &&
            _mmCountryNotifier.value != null);

    final String label;
    final String iconAsset;
    if (method == BidPaymentMethod.cash) {
      label = 'Confirmer (paiement en espèces)';
      iconAsset = 'banknote';
    } else if (method == BidPaymentMethod.wave) {
      label = 'Payer via Wave';
      iconAsset = 'waves';
    } else if (method == BidPaymentMethod.orangeMoney) {
      label = 'Payer via Orange Money';
      iconAsset = 'smartphone';
    } else {
      final total = _computeStripeTotal();
      label =
          'Bloquer ${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(total)} & payer';
      iconAsset = 'lock';
    }

    widget.btnConfigNotifier.value = _BtnConfig(
      label: label,
      iconAsset: iconAsset,
      onPressed: mmOk ? _confirmPayment : null,
    );
  }

  double _computeStripeTotal() {
    final quote = _quoteNotifier.value;
    // Le devis serveur couvre tous les modes (poids + articles + promo).
    if (quote is BidQuoteResponse) return quote.totalEur;
    final data = _formData;
    if (data == null) return 0.0;
    // Repli local : part poids (commission incl.) + part articles (déjà commission incl.).
    return netToSenderPrice(data.weightKg * _pricePerKg) + _gridDisplayTotal();
  }

  // ── Navigation between steps ───────────────────────────────────────────────

  void _goToPicker() {
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

    final promoCode = _promoCtrl.text.trim().isNotEmpty
        ? _promoCtrl.text.trim()
        : null;
    _formData = _CollectedFormData(
      weightKg: _weightNotifier.value,
      declaredValueEur: val,
      description: _descCtrl.text.trim(),
      contentCategory: _categoriesNotifier.value.join(', '),
      recipientName: _recipientNameCtrl.text.trim(),
      recipientPhone: _recipientPhoneCtrl.text.trim(),
      gridItems: _selectedGridItems(),
      promoCode: promoCode,
    );

    // If only Stripe is available, skip the picker and go straight to checkout.
    if (!_hasAlternativePaymentMethods) {
      _confirmPayment();
      return;
    }

    _stepNotifier.value = _FormStep.paymentPicker;
  }

  // ── Dispatch BidBloc event ─────────────────────────────────────────────────

  void _confirmPayment() {
    final data = _formData;
    if (data == null) return;
    final method = _methodNotifier.value;

    if (method == BidPaymentMethod.wave ||
        method == BidPaymentMethod.orangeMoney) {
      final phone = _mmPhoneCtrl.text.trim();
      if (phone.isEmpty) {
        _showError('Numéro Mobile Money obligatoire');
        return;
      }
      if (_mmCountryNotifier.value == null) {
        _showError('Pays obligatoire');
        return;
      }
      widget.bidBloc.add(BidCreateRequested(
        announcementId: widget.announcement.id,
        weightKg: data.weightKg,
        declaredValueEur: data.declaredValueEur,
        description: data.description,
        contentCategory: data.contentCategory,
        recipientName: data.recipientName,
        recipientPhone: data.recipientPhone,
        paymentMethod: method,
        phoneNumber: phone,
        countryCode: _mmCountryNotifier.value,
        promoCode: data.promoCode,
        gridItems: data.gridItems,
      ));
    } else if (method == BidPaymentMethod.cash) {
      widget.bidBloc.add(BidCreateRequested(
        announcementId: widget.announcement.id,
        weightKg: data.weightKg,
        declaredValueEur: data.declaredValueEur,
        description: data.description,
        contentCategory: data.contentCategory,
        recipientName: data.recipientName,
        recipientPhone: data.recipientPhone,
        paymentMethod: BidPaymentMethod.cash,
        promoCode: data.promoCode,
        gridItems: data.gridItems,
      ));
    } else {
      widget.bidBloc.add(BidCheckoutRequested(
        announcementId: widget.announcement.id,
        weightKg: data.weightKg,
        declaredValueEur: data.declaredValueEur,
        description: data.description,
        contentCategory: data.contentCategory,
        recipientName: data.recipientName,
        recipientPhone: data.recipientPhone,
        gridItems: data.gridItems,
      ));
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _mmPhoneCtrl.dispose();
    _weightNotifier.removeListener(_syncFormButtonState);
    _categoriesNotifier.removeListener(_syncFormButtonState);
    _disclaimerNotifier.removeListener(_syncFormButtonState);
    _gridQuantitiesNotifier.removeListener(_syncFormButtonState);
    _weightNotifier.removeListener(_invalidateQuote);
    _gridQuantitiesNotifier.removeListener(_invalidateQuote);
    _stepNotifier.removeListener(_onStepChanged);
    _methodNotifier.removeListener(_syncPickerButtonState);
    _mmPhoneCtrl.removeListener(_syncPickerButtonState);
    _mmCountryNotifier.removeListener(_syncPickerButtonState);
    _promoCtrl.dispose();
    _quoteNotifier.dispose();
    _weightNotifier.dispose();
    _categoriesNotifier.dispose();
    _disclaimerNotifier.dispose();
    _gridQuantitiesNotifier.dispose();
    _stepNotifier.dispose();
    _methodNotifier.dispose();
    _mmCountryNotifier.dispose();
    super.dispose();
  }

  void _showError(String message) {
    DonySnackbar.show(context, message: message, type: DonySnackbarType.error);
  }

  // ── BLoC event handlers ────────────────────────────────────────────────────

  void _onBidState(BuildContext context, BidState state) {
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
    } else if (state is BidQuoteLoaded) {
      _quoteNotifier.value = state.quote;
    } else if (state is BidPromoError) {
      _quoteNotifier.value = state.error.message;
      ErrorPresenter.show(context, state.error);
    } else if (state is BidError) {
      ErrorPresenter.show(context, state.error);
    }
  }

  Future<void> _onPaymentState(BuildContext context, PaymentState state) async {
    if (state is CheckoutPaymentSheetReady) {
      await _presentPaymentSheet(context, state);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BidBloc, BidState>(listener: _onBidState),
        BlocListener<PaymentBloc, PaymentState>(listener: _onPaymentState),
      ],
      child: ValueListenableBuilder<_FormStep>(
        valueListenable: _stepNotifier,
        builder: (context, step, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: step == _FormStep.paymentPicker
                ? _buildPickerStep(context)
                : _buildFormStep(context),
          );
        },
      ),
    );
  }

  // ── Form step ──────────────────────────────────────────────────────────────

  Widget _buildFormStep(BuildContext context) {
    return ListenableBuilder(
      key: const ValueKey('form'),
      listenable: Listenable.merge([
        _weightNotifier,
        _categoriesNotifier,
        _disclaimerNotifier,
        _gridQuantitiesNotifier,
      ]),
      builder: (context, _) {
        final weightKg = _weightNotifier.value;
        final categories = _categoriesNotifier.value;
        final disclaimerAccepted = _disclaimerNotifier.value;
        final gridQuantities = _gridQuantitiesNotifier.value;
        final hasGridPricing = widget.announcement.priceGridItems.isNotEmpty;
        final hasKgPricing = widget.announcement.pricePerKg > 0;

        final gridTotal = hasGridPricing
            ? widget.announcement.priceGridItems.fold<double>(
                0,
                (sum, item) =>
                    sum + item.unitPriceDisplay * (gridQuantities[item.id] ?? 0),
              )
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Articles grille ─────────────────────────────────────────────
            if (hasGridPricing) ...[
              const _SectionLabel(label: 'ARTICLES'),
              const SizedBox(height: DonySpacing.sm),
              ValueListenableBuilder<Map<String, int>>(
                valueListenable: _gridQuantitiesNotifier,
                builder: (context, quantities, _) {
                  final totalSelected =
                      quantities.values.fold<int>(0, (s, q) => s + q);
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
                        borderRadius: BorderRadius.circular(DonyRadius.card),
                        border: hasSelection
                            ? Border.all(
                                color:
                                    Theme.of(context).colorScheme.success,
                                width: 1.5,
                              )
                            : Border.all(
                                color:
                                    Theme.of(context).colorScheme.warning,
                                width: 1.5,
                              ),
                      ),
                      child: hasSelection
                          ? Row(
                              children: [
                                DonyIcon(
                                  'circle-check',
                                  color:
                                      Theme.of(context).colorScheme.success,
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
                                              fontWeight: FontWeight.w600,
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
                                const DonyEmoji.parcel(size: 18),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Choisir mes articles',
                                        key: const Key('choose-articles-btn'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
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
                                DonyIcon(
                                  'chevron-right',
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

            // ── Poids ───────────────────────────────────────────────────────
            if (hasKgPricing) ...[
              _WeightSection(
                weightKg: weightKg,
                maxKg: _maxKg,
                isMixed: hasGridPricing,
                isKgFree: widget.announcement.isKgFree,
                onChanged: (v) => _weightNotifier.value = v,
              ).animate().fadeIn(duration: 250.ms),
              const SizedBox(height: DonySpacing.xxl),
            ],

            // ── Contenu ─────────────────────────────────────────────────────
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

            // ── Description ─────────────────────────────────────────────────
            const _SectionLabel(label: 'DESCRIPTION (AU VOYAGEUR)'),
            const SizedBox(height: DonySpacing.sm),
            DonyTextField(
              controller: _descCtrl,
              hint: 'Médicaments pour diabète + 2 tee-shirts enfants',
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: DonySpacing.xxl),

            // ── Valeur déclarée ─────────────────────────────────────────────
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
                helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base,
                  vertical: DonySpacing.md,
                ),
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ).animate().fadeIn(delay: 140.ms),
            const SizedBox(height: DonySpacing.xxl),

            // ── Destinataire ────────────────────────────────────────────────
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

            // ── Disclaimer ──────────────────────────────────────────────────
            _DisclaimerCard(
              accepted: disclaimerAccepted,
              onChanged: (v) => _disclaimerNotifier.value = v,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: DonySpacing.xxl),

            // ── Code promo ──────────────────────────────────────────────────
            const _SectionLabel(label: 'CODE PROMO (OPTIONNEL)'),
            const SizedBox(height: DonySpacing.sm),
            BlocBuilder<BidBloc, BidState>(
              bloc: widget.bidBloc,
              builder: (context, bidState) {
                final isQuoteLoading = bidState is BidQuoteLoading;
                return ValueListenableBuilder<Object?>(
                  valueListenable: _quoteNotifier,
                  builder: (_, quoteVal, __) {
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
                );
              },
            ).animate().fadeIn(delay: 220.ms),
            const SizedBox(height: DonySpacing.xxl),

            // ── Prix (live, tous modes, promo inclus) ────────────────────────
            ValueListenableBuilder<Object?>(
              valueListenable: _quoteNotifier,
              builder: (_, quoteVal, __) {
                final quote = quoteVal is BidQuoteResponse ? quoteVal : null;
                final kgDisplayLocal =
                    hasKgPricing ? netToSenderPrice(weightKg * _pricePerKg) : 0.0;
                final localTotal = kgDisplayLocal + gridTotal;

                double kgLine = kgDisplayLocal;
                double gridLine = gridTotal;
                double total = localTotal;
                double? original;
                bool promoApplied = false;
                if (quote != null) {
                  // Devis serveur : lignes recalculées au taux effectif → somme = total.
                  final mult = 1 + quote.rate;
                  kgLine = quote.kgNetEur * mult;
                  gridLine = quote.gridNetEur * mult;
                  total = quote.totalEur;
                  promoApplied = quote.promoApplied;
                  original = promoApplied ? localTotal : null;
                }
                if (total <= 0) return const SizedBox.shrink();
                return _PriceBreakdown(
                  weightKg: weightKg,
                  pricePerKg: _pricePerKg,
                  kgDisplay: kgLine,
                  gridDisplay: gridLine,
                  totalPrice: total,
                  originalTotal: original,
                  promoApplied: promoApplied,
                );
              },
            ),
            const SizedBox(height: DonySpacing.md),
          ],
        );
      },
    );
  }

  // ── Picker step ────────────────────────────────────────────────────────────

  Widget _buildPickerStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey('picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back to form
        GestureDetector(
          onTap: () => _stepNotifier.value = _FormStep.form,
          child: Row(
            children: [
              DonyIcon('chevron-left',
                  size: 16, color: cs.primary),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Retour',
                style:
                    tt.labelMedium?.copyWith(color: cs.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.xl),

        Text(
          'Comment veux-tu payer ?',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Choisis le mode de paiement pour cette demande.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.xl),

        // Method selector
        ValueListenableBuilder<BidPaymentMethod>(
          valueListenable: _methodNotifier,
          builder: (context, method, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PaymentMethodSelector(
                  selectedMethod: method,
                  onChanged: (m) => _methodNotifier.value = m,
                  isCashAvailable: widget.isCashAvailable,
                  isWaveAvailable: widget.isWaveAvailable,
                  isOrangeMoneyAvailable: widget.isOrangeMoneyAvailable,
                ),

                // Mobile Money extra fields
                if (method == BidPaymentMethod.wave ||
                    method == BidPaymentMethod.orangeMoney) ...[
                  const SizedBox(height: DonySpacing.xxl),
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
                    builder: (context, selectedCountry, _) =>
                        DropdownButtonFormField<String>(
                      initialValue: selectedCountry,
                      decoration: const InputDecoration(
                        labelText: 'Pays Mobile Money',
                        contentPadding: EdgeInsets.symmetric(
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
                    ).animate().fadeIn(delay: 40.ms),
                  ),
                ],
              ],
            );
          },
        ),

        // Compte Dony — solde disponible + accès recharge (porté de feat/wallet).
        // Affiché sous le sélecteur de mode : informatif, non sélectionnable
        // (wallet n'est pas un BidPaymentMethod).
        BlocBuilder<WalletBloc, WalletState>(
          builder: (ctx, walletState) {
            if (walletState is! WalletLoaded) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: DonySpacing.xl),
                _WalletTile(balance: walletState.wallet.balance),
              ],
            );
          },
        ).animate().fadeIn(delay: 195.ms),

        const SizedBox(height: DonySpacing.md),
      ],
    ).animate().fadeIn(duration: 220.ms);
  }

  // ── Stripe payment sheet ───────────────────────────────────────────────────

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
      context.read<BidBloc>().add(BidConfirmPaymentRequested(state.bidId));
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
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

class _WeightSection extends StatefulWidget {
  const _WeightSection({
    required this.weightKg,
    required this.maxKg,
    required this.onChanged,
    this.isMixed = false,
    this.isKgFree = false,
  });

  final double weightKg;
  final double maxKg;
  final ValueChanged<double> onChanged;
  final bool isMixed;

  /// Trajet « kilo libre » : capacité non bornée → saisie/stepper sans maximum.
  final bool isKgFree;

  @override
  State<_WeightSection> createState() => _WeightSectionState();
}

class _WeightSectionState extends State<_WeightSection> {
  TextEditingController? _kgCtrl;
  FocusNode? _kgFocus;

  double get _min => widget.isMixed ? 0.0 : 1.0;

  @override
  void initState() {
    super.initState();
    if (widget.isKgFree) {
      _kgCtrl = TextEditingController(text: widget.weightKg.toStringAsFixed(0));
      _kgFocus = FocusNode()..addListener(_onFocusChanged);
    }
  }

  @override
  void didUpdateWidget(covariant _WeightSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Garde le champ synchronisé quand la valeur change via les steppers,
    // sans interférer pendant une saisie en cours. Tant que le champ a le
    // focus, on laisse l'utilisateur saisir librement (y compris vider le
    // champ pour retaper un nombre) : aucune réécriture pendant l'édition.
    final ctrl = _kgCtrl;
    if (ctrl != null && !(_kgFocus?.hasFocus ?? false)) {
      final current = double.tryParse(ctrl.text.trim());
      if (current == null || current != widget.weightKg) {
        final text = widget.weightKg.toStringAsFixed(0);
        ctrl.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _kgFocus?.removeListener(_onFocusChanged);
    _kgFocus?.dispose();
    _kgCtrl?.dispose();
    super.dispose();
  }

  void _setWeight(double value) {
    final clamped = value < _min ? _min : value;
    widget.onChanged(clamped);
  }

  /// À la perte de focus, un champ vide/invalide retombe au minimum et le
  /// texte est resynchronisé avec la valeur réelle (sans plafond haut).
  void _onFocusChanged() {
    if (_kgFocus?.hasFocus ?? false) {
      return;
    }
    final ctrl = _kgCtrl;
    if (ctrl == null) {
      return;
    }
    final parsed = double.tryParse(ctrl.text.trim());
    final value = parsed == null ? _min : (parsed < _min ? _min : parsed);
    if (value != widget.weightKg) {
      widget.onChanged(value);
    }
    final text = value.toStringAsFixed(0);
    if (ctrl.text != text) {
      ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _onFieldChanged(String raw) {
    final trimmed = raw.trim();
    // Champ vidé / saisie transitoire → on ne coerce pas et on ne pousse rien
    // au parent : l'utilisateur peut vider le champ pour retaper « 42 ». La
    // coercition au minimum est différée à la perte de focus (_onFocusChanged).
    if (trimmed.isEmpty) {
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return;
    }
    // Pas de plafond haut ; on borne uniquement le minimum.
    final value = parsed < _min ? _min : parsed;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return widget.isKgFree ? _buildKgFree(context) : _buildSlider(context);
  }

  // ── Kilo libre : saisie + steppers, sans maximum ────────────────────────────

  Widget _buildKgFree(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final weightKg = widget.weightKg;
    final canDecrement = weightKg > _min;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isMixed ? 'Poids du colis (optionnel)' : 'Poids du colis',
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.xxs),
        Text(
          'Kilo libre — choisissez votre poids',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.md),
        Row(
          children: [
            _StepperButton(
              key: const Key('weight-decrement'),
              iconAsset: 'minus',
              onPressed: canDecrement
                  ? () => _setWeight(weightKg - 1)
                  : null,
            ),
            const SizedBox(width: DonySpacing.base),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IntrinsicWidth(
                    child: TextField(
                      key: const Key('weight-field'),
                      controller: _kgCtrl,
                      focusNode: _kgFocus,
                      onChanged: _onFieldChanged,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      textAlign: TextAlign.center,
                      style: tt.displayLarge?.copyWith(color: cs.onSurface),
                      cursorColor: cs.primary,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
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
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.base),
            _StepperButton(
              key: const Key('weight-increment'),
              iconAsset: 'plus',
              onPressed: () => _setWeight(weightKg + 1),
            ),
          ],
        ),
      ],
    );
  }

  // ── Trajet borné : slider sur la capacité restante (inchangé) ────────────────

  Widget _buildSlider(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isMixed = widget.isMixed;
    final maxKg = widget.maxKg;
    final weightKg = widget.weightKg;
    final onChanged = widget.onChanged;
    final sliderMin = isMixed ? 0.0 : 1.0;

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
        Row(
          children: [
            Text(
              isMixed ? 'Poids du colis (optionnel)' : 'Poids du colis',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
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
                style:
                    tt.headlineMedium?.copyWith(color: cs.onSurfaceVariant),
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

// ── Stepper button (kilo libre) ──────────────────────────────────────────────

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.iconAsset,
    required this.onPressed,
  });

  final String iconAsset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? cs.primaryContainer : cs.surfaceContainerLow,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: DonyIcon(
                iconAsset,
                size: 22,
                color: enabled ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
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
              DonyIcon('check', size: 14, color: cs.surface),
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
        borderRadius:
            const BorderRadius.all(Radius.circular(DonyRadius.card)),
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
              DonyIcon('triangle-alert',
                  size: 20, color: cs.secondary),
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
                      style: tt.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer, height: 1.5),
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
          iconAsset: 'lock',
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
            iconAsset: 'banknote',
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
            iconAsset: 'waves',
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
            iconAsset: 'smartphone',
            label: 'Orange Money',
            sublabel: 'Mobile Money',
            selected: selectedMethod == BidPaymentMethod.orangeMoney,
            onTap: () => onChanged(BidPaymentMethod.orangeMoney),
          ),
        ),
      ],
    ];

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
    required this.iconAsset,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final String iconAsset;
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
            DonyIcon(
              iconAsset,
              color: selected ? cs.primary : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color:
                    selected ? cs.onPrimaryContainer : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              sublabel,
              style: tt.bodySmall?.copyWith(
                color: selected
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid total recap ─────────────────────────────────────────────────────────

// ── Wallet tile (Compte Dony) ────────────────────────────────────────────────

class _WalletTile extends StatelessWidget {
  const _WalletTile({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final hasBalance = balance > 0;

    return GestureDetector(
      onTap: hasBalance
          ? null
          : () => context.push('/payments/wallet'),
      child: AnimatedContainer(
        duration: 150.ms,
        width: double.infinity,
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: hasBalance
              ? cs.surfaceContainerLow
              : cs.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: hasBalance ? cs.outline : cs.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            DonyIcon(
              'wallet',
              color: hasBalance ? cs.primary : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compte Dony',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hasBalance
                        ? 'Solde disponible : ${fmt.format(balance)}'
                        : 'Solde insuffisant · Recharger',
                    style: tt.bodySmall?.copyWith(
                      color: hasBalance
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!hasBalance)
              DonyIcon(
                'chevron-right',
                color: cs.onSurfaceVariant,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Price breakdown ───────────────────────────────────────────────────────────

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({
    required this.weightKg,
    required this.pricePerKg,
    required this.kgDisplay,
    required this.gridDisplay,
    required this.totalPrice,
    this.originalTotal,
    this.promoApplied = false,
  });

  final double weightKg;
  final double pricePerKg;

  /// Part « poids » au prix expéditeur (commission Dony incluse). 0 si pas de poids.
  final double kgDisplay;

  /// Part « articles » au prix expéditeur (commission Dony incluse). 0 si pas d'article.
  final double gridDisplay;

  /// Total à payer par l'expéditeur.
  final double totalPrice;

  /// Total avant promo (barré) — null si pas de promo.
  final double? originalTotal;

  final bool promoApplied;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    final lines = <Widget>[];
    if (weightKg > 0 && kgDisplay > 0) {
      lines.add(_line(
        tt,
        '${formatKgPrice(weightKg)} kg × ${formatKgPrice(pricePerKg)}€',
        fmt.format(kgDisplay),
      ));
    }
    if (gridDisplay > 0) {
      lines.add(_line(tt, 'Articles', fmt.format(gridDisplay)));
    }

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines) ...[
            l,
            const SizedBox(height: DonySpacing.xs),
          ],
          if (lines.isNotEmpty) ...[
            Divider(color: cs.outline),
            const SizedBox(height: DonySpacing.xs),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Total', style: tt.titleLarge),
                  if (promoApplied) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Promo',
                        style: tt.labelSmall?.copyWith(
                          color: const Color(0xFF16A34A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (promoApplied && originalTotal != null) ...[
                    Text(
                      fmt.format(originalTotal),
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    fmt.format(totalPrice),
                    key: const Key('bid-total-amount'),
                    style: tt.titleLarge?.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Commission Dony incluse',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _line(TextTheme tt, String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium),
          Text(value, style: tt.titleMedium),
        ],
      );
}
