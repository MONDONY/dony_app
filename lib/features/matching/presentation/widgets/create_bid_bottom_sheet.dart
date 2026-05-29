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
    required this.icon,
    this.onPressed,
  });
  final String label;
  final IconData icon;
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
  });
  final double weightKg;
  final double declaredValueEur;
  final String description;
  final String contentCategory;
  final String recipientName;
  final String recipientPhone;
  final List<Map<String, dynamic>>? gridItems;
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
      icon: Icons.send_rounded,
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
              icon: config?.icon ?? Icons.send_rounded,
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

  // ── Picker step fields ─────────────────────────────────────────────────────
  final _methodNotifier =
      ValueNotifier<BidPaymentMethod>(BidPaymentMethod.stripe);
  final _mmPhoneCtrl = TextEditingController();
  final _mmCountryNotifier = ValueNotifier<String?>('CI');

  double get _maxKg => widget.announcement.availableKg;
  double get _pricePerKg => widget.announcement.pricePerKg;

  bool get _hasAlternativePaymentMethods =>
      widget.isCashAvailable ||
      widget.isWaveAvailable ||
      widget.isOrangeMoneyAvailable;

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

    // Form step listeners
    _weightNotifier.addListener(_syncFormButtonState);
    _categoriesNotifier.addListener(_syncFormButtonState);
    _disclaimerNotifier.addListener(_syncFormButtonState);
    _gridQuantitiesNotifier.addListener(_syncFormButtonState);

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
      icon: Icons.send_rounded,
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
    final IconData icon;
    if (method == BidPaymentMethod.cash) {
      label = 'Confirmer (paiement en espèces)';
      icon = Icons.payments_rounded;
    } else if (method == BidPaymentMethod.wave) {
      label = 'Payer via Wave';
      icon = Icons.waves_rounded;
    } else if (method == BidPaymentMethod.orangeMoney) {
      label = 'Payer via Orange Money';
      icon = Icons.phone_android_rounded;
    } else {
      final total = _computeStripeTotal();
      label =
          'Bloquer ${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(total)} & payer';
      icon = Icons.lock_rounded;
    }

    widget.btnConfigNotifier.value = _BtnConfig(
      label: label,
      icon: icon,
      onPressed: mmOk ? _confirmPayment : null,
    );
  }

  double _computeStripeTotal() {
    final data = _formData;
    if (data == null) return 0.0;
    return data.weightKg * _pricePerKg * 1.12;
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

    final gridItems = widget.announcement.priceGridItems
        .where((item) => (_gridQuantitiesNotifier.value[item.id] ?? 0) > 0)
        .map((item) => {
              'announcementGridItemId': item.id,
              'quantity': _gridQuantitiesNotifier.value[item.id]!,
            })
        .toList();

    _formData = _CollectedFormData(
      weightKg: _weightNotifier.value,
      declaredValueEur: val,
      description: _descCtrl.text.trim(),
      contentCategory: _categoriesNotifier.value.join(', '),
      recipientName: _recipientNameCtrl.text.trim(),
      recipientPhone: _recipientPhoneCtrl.text.trim(),
      gridItems: gridItems.isEmpty ? null : gridItems,
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
    _stepNotifier.removeListener(_onStepChanged);
    _methodNotifier.removeListener(_syncPickerButtonState);
    _mmPhoneCtrl.removeListener(_syncPickerButtonState);
    _mmCountryNotifier.removeListener(_syncPickerButtonState);
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
        final serviceFee = weightKg * _pricePerKg * 0.12;
        final basePrice = weightKg * _pricePerKg;
        final totalPrice = basePrice + serviceFee;

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
                                Icon(
                                  Icons.check_circle_rounded,
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
                                Icon(
                                  Icons.inventory_2_outlined,
                                  color:
                                      Theme.of(context).colorScheme.warning,
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

            // ── Poids ───────────────────────────────────────────────────────
            if (hasKgPricing) ...[
              _WeightSection(
                weightKg: weightKg,
                maxKg: _maxKg,
                isMixed: hasGridPricing,
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

            // ── Récap grille ────────────────────────────────────────────────
            if (hasGridPricing && gridTotal > 0) ...[
              _GridTotalRecap(gridTotal: gridTotal),
              const SizedBox(height: DonySpacing.md),
            ],

            // ── Prix ────────────────────────────────────────────────────────
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
              Icon(Icons.arrow_back_ios_rounded,
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
  final bool isMixed;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
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
              Icon(Icons.warning_amber_rounded,
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
            Icon(
              Icons.account_balance_wallet_rounded,
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
              Icon(
                Icons.chevron_right_rounded,
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
                style:
                    tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
