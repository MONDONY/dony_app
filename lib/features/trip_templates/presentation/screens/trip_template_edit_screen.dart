import 'dart:async';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/presentation/widgets/city_corridor_fields.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/currency_selection_banner.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_fields.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_active.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TripTemplateEditScreen extends StatefulWidget {
  const TripTemplateEditScreen({super.key, this.template});

  final TripTemplate? template;

  @override
  State<TripTemplateEditScreen> createState() => _TripTemplateEditScreenState();
}

class _TripTemplateEditScreenState extends State<TripTemplateEditScreen> {
  static const _totalSteps = 3;

  static List<(int?, String)> _handoverChoices(AppLocalizations l) => [
    (null, l.tripTemplateHandoverNone),
    (0, l.tripTemplateHandoverSameDay),
    (1, l.tripTemplateHandoverDaysBefore(1)),
    (2, l.tripTemplateHandoverDaysBefore(2)),
    (3, l.tripTemplateHandoverDaysBefore(3)),
    (7, l.tripTemplateHandoverDaysBefore(7)),
  ];

  late final TripFormFields _fields;
  final _labelCtrl = TextEditingController();
  final _step = ValueNotifier<int>(0);
  final _handoverLeadDays = ValueNotifier<int?>(null);
  final _canContinue = ValueNotifier<bool>(false);
  bool _submitted = false;

  bool get _isEditing => widget.template != null;

  @visibleForTesting
  int? get handoverLeadDaysForTest => _handoverLeadDays.value;
  @visibleForTesting
  TripFormFields get fieldsForTest => _fields;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _fields = TripFormFields(
      initialCurrency:
          SupportedCurrency.fromCode(t?.currency) ??
          ActiveCurrency.current ??
          SupportedCurrency.eur,
    );
    _fields.transportMode.value = TransportMode.plane;
    if (t != null) {
      _prefill(t);
      // Remet mobile money à faux si la devise du modèle n'est pas éligible
      // (même garde que la bascule manuelle du sélecteur de devise) : un
      // modèle enregistré avant une restriction de zone CFA ne doit pas
      // rester coché.
      _onCurrencyChanged();
    }
    _labelCtrl.addListener(_recomputeCanContinue);
    _fields.departureCity.addListener(_recomputeCanContinue);
    _fields.arrivalCity.addListener(_recomputeCanContinue);
    _fields.transportMode.addListener(_recomputeCanContinue);
    _step.addListener(_recomputeCanContinue);
    _fields.priceOption.addListener(_recomputeCanContinue);
    _fields.customPriceCtrl.addListener(_recomputeCanContinue);
    _fields.kgPriceEnabled.addListener(_recomputeCanContinue);
    _fields.currency.addListener(_recomputeCanContinue);
    _recomputeCanContinue();

    unawaited(_loadCatalog());

    // Synchronisations étape 2 → AnnouncementFormBloc, même règles que
    // `_TripFormContentState` (create_trip_screen.dart) : LieuxCapaciteStep
    // (CapacityControl) et PrixConditionsStep (mode de tarification) lisent
    // et écrivent directement dans ce bloc.
    _fields.priceOption.addListener(_syncPriceToFormBloc);
    _fields.customPrice.addListener(_syncPriceToFormBloc);
    _fields.availableKg.addListener(_syncKgToFormBloc);
    _fields.kgPriceEnabled.addListener(_onKgToggleChanged);
    _fields.currency.addListener(_onCurrencyChanged);
  }

  Future<void> _loadCatalog() async {
    final categories = await getIt<IContentCategoryRepository>()
        .getCategories();
    if (!mounted) return;
    _fields.catalogLabels.value = categories.map((c) => c.label).toList();
  }

  void _syncPriceToFormBloc() {
    if (!mounted) return;
    if (!_fields.kgPriceEnabled.value) return; // évite d'écraser le clear
    if (_fields.priceOption.value == -1) return; // pas encore de sélection
    context.read<AnnouncementFormBloc>().add(
      PriceChanged(_fields.pricePerKg!, currency: _fields.currency.value),
    );
  }

  /// Vrai le temps que le `BlocListener` du `build()` recopie
  /// `state.availableKg` dans `_fields.availableKg` : cette écriture vient du
  /// bloc, la lui renvoyer serait un écho. Sans cette garde, le préremplissage
  /// (`CapacityUnitChanged` puis `AvailableKgChanged`) laisse deux valeurs
  /// différentes en file qui se relancent l'une l'autre sans fin — une boucle
  /// de microtâches où les timers ne tournent jamais, donc que `--timeout` ne
  /// coupe pas (le run de tests part à 100 % de CPU indéfiniment).
  bool _applyingKgFromBloc = false;

  void _syncKgToFormBloc() {
    if (!mounted || _applyingKgFromBloc) return;
    final bloc = context.read<AnnouncementFormBloc>();
    if (bloc.state.availableKg == _fields.availableKg.value) return;
    bloc.add(AvailableKgChanged(_fields.availableKg.value));
  }

  void _onKgToggleChanged() {
    if (!mounted) return;
    if (!_fields.kgPriceEnabled.value) {
      context.read<AnnouncementFormBloc>().add(
        const AnnouncementPricePerKgClearedRequested(),
      );
      _fields.priceOption.value = 0; // reset chips visuellement
    }
  }

  /// Remet la bascule mobile money à `false` quand la devise quitte la zone
  /// CFA (XOF/XAF) — même règle que `_TripFormContentState._onCurrencyChanged`.
  void _onCurrencyChanged() {
    if (!_fields.currency.value.isMobileMoneyEligible) {
      _fields.mobileMoneyEnabled.value = false;
    }
    _syncPriceToFormBloc();
  }

  void _prefill(TripTemplate t) {
    _labelCtrl.text = t.label;
    _fields.departureCity.value = t.departureCity;
    _fields.arrivalCity.value = t.arrivalCity;
    _fields.departureCountryCode.value = t.departureCountryCode;
    _fields.arrivalCountryCode.value = t.arrivalCountryCode;
    _fields.transportMode.value =
        transportModeFromWire(t.transportMode) ?? TransportMode.plane;
    _fields.departureTime.value = _timeOfDay(t.departureTime);
    _fields.arrivalTime.value = _timeOfDay(t.arrivalTime);
    _handoverLeadDays.value = t.handoverLeadDays;
    _prefillConditions(t);
  }

  /// Préremplissage des étapes 1 (Lieux & capacité) et 2 (Prix & conditions)
  /// depuis un modèle existant. Le split catalogue/custom des catégories est
  /// celui de `_applyTemplate` (create_trip_screen.dart) : le catalogue n'est
  /// pas forcément chargé à cet instant, la liste par défaut de
  /// [TripFormFields.catalogLabels] (repli embarqué) sert de référence.
  void _prefillConditions(TripTemplate t) {
    _fields.pickupAddress.value = t.pickupAddress;
    _fields.deliveryAddress.value = t.deliveryAddress;
    _fields.availableKg.value = t.availableKg.toDouble();
    _fields.kgPriceEnabled.value = !t.usesPriceGrid || t.pricePerKg != null;
    _fields.selectPrice(t.pricePerKg);
    _fields.cashEnabled.value = t.acceptedPaymentMethods.contains('CASH');
    _fields.mobileMoneyEnabled.value = t.acceptedPaymentMethods.contains(
      'MOBILE_MONEY',
    );
    _fields.negotiable.value = t.negotiable;
    _fields.selectedContent.value = t.acceptedCategories
        .where(_fields.catalogLabels.value.contains)
        .toSet();
    _fields.customAccepted.value = t.acceptedCategories
        .where((c) => !_fields.catalogLabels.value.contains(c))
        .toSet();
    _fields.refusedTypes.value = t.refusedTypes.toSet();
    _fields.descriptionCtrl.text = t.description ?? '';

    // Sync capacityUnit et availableKg vers le bloc (requiert context →
    // postFrame), même pattern que `_applyTemplate` (create_trip_screen.dart).
    // Ordre impératif : `CapacityUnitChanged` réécrit `availableKg` à
    // `unit.maxKg` (valise 23/32 kg) — `AvailableKgChanged` doit donc être
    // émis APRÈS pour que la valeur du modèle prime (sinon un modèle
    // « valise 32 kg, 64 kg » s'appliquerait à 32 kg). Le `BlocListener`
    // du `build()` recopie ensuite `state.availableKg` dans
    // `_fields.availableKg`, seul point d'écriture attendu par
    // `CapacityControl` (Tâche 1, constat #1).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final formBloc = context.read<AnnouncementFormBloc>();
      final unit = switch (t.capacityUnit) {
        'KG_FREE' => CapacityUnit.kgFree,
        'SUITCASE_32KG' => CapacityUnit.suitcase32kg,
        'KG_EXACT' => CapacityUnit.custom,
        _ => CapacityUnit.suitcase23kg,
      };
      formBloc.add(CapacityUnitChanged(unit));
      formBloc.add(AvailableKgChanged(t.availableKg.toDouble()));
      formBloc.add(
        AnnouncementPricingModeSetRequested(
          t.usesPriceGrid ? PricingMode.mixed : PricingMode.kg,
        ),
      );
    });
  }

  static TimeOfDay? _timeOfDay(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String? _wire(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Étape 0 : nom, villes et transport. Étape 1 (Lieux & capacité) :
  /// adresses optionnelles dans un modèle, toujours valide. Étape 2 (Prix &
  /// conditions) : prix requis si le tarif au kilo est actif, borné par
  /// [maxUnitPriceFor] si c'est un prix libre.
  void _recomputeCanContinue() {
    final step0Ok =
        _labelCtrl.text.trim().isNotEmpty &&
        (_fields.departureCity.value?.trim().isNotEmpty ?? false) &&
        (_fields.arrivalCity.value?.trim().isNotEmpty ?? false) &&
        _fields.transportMode.value != null;
    var step2Ok = !_fields.kgPriceEnabled.value || _fields.pricePerKg != null;
    if (step2Ok && _fields.isCustomPrice) {
      final parsed = parsePriceInput(_fields.customPriceCtrl.text);
      step2Ok =
          parsed != null &&
          parsed > 0 &&
          parsed <= maxUnitPriceFor(_fields.currency.value);
    }
    _canContinue.value = switch (_step.value) {
      0 => step0Ok,
      1 => true,
      _ => step2Ok,
    };
  }

  @override
  void dispose() {
    _fields.priceOption.removeListener(_recomputeCanContinue);
    _fields.customPriceCtrl.removeListener(_recomputeCanContinue);
    _fields.kgPriceEnabled.removeListener(_recomputeCanContinue);
    _fields.currency.removeListener(_recomputeCanContinue);
    _fields.priceOption.removeListener(_syncPriceToFormBloc);
    _fields.customPrice.removeListener(_syncPriceToFormBloc);
    _fields.availableKg.removeListener(_syncKgToFormBloc);
    _fields.kgPriceEnabled.removeListener(_onKgToggleChanged);
    _fields.currency.removeListener(_onCurrencyChanged);
    _labelCtrl.dispose();
    _step.dispose();
    _handoverLeadDays.dispose();
    _canContinue.dispose();
    _fields.dispose();
    super.dispose();
  }

  /// Payload complet envoyé au bloc : les trois étapes (Trajet, Lieux &
  /// capacité, Prix & conditions), sérialisées par `TripTemplate.toJson` —
  /// même mapping adresse/champs que le modèle chargé depuis le repository,
  /// pas de duplication locale (constat #10).
  Map<String, dynamic> _buildPayload(BuildContext context) {
    final formState = context.read<AnnouncementFormBloc>().state;
    final stripeState = context.read<StripeAccountBloc>().state;
    final stripeConfigured =
        stripeState is StripeAccountReady &&
        stripeState.accountStatus.isComplete;
    final template = TripTemplate(
      id: widget.template?.id ?? '',
      label: _labelCtrl.text.trim(),
      emoji: widget.template?.emoji,
      departureCity: _fields.departureCity.value?.trim() ?? '',
      departureLat: widget.template?.departureLat,
      departureLng: widget.template?.departureLng,
      arrivalCity: _fields.arrivalCity.value?.trim() ?? '',
      arrivalLat: widget.template?.arrivalLat,
      arrivalLng: widget.template?.arrivalLng,
      departureCountryCode: _fields.departureCountryCode.value,
      arrivalCountryCode: _fields.arrivalCountryCode.value,
      transportMode: transportModeToWire(
        _fields.transportMode.value ?? TransportMode.plane,
      ),
      capacityUnit: formState.capacityUnit.toWire(),
      availableKg: _fields.availableKg.value.round(),
      pricingMode: formState.pricingMode == PricingMode.mixed ? 'MIXED' : 'KG',
      pricePerKg: _fields.pricePerKg,
      acceptedCategories: {
        ..._fields.selectedContent.value,
        ..._fields.customAccepted.value,
      }.toList(),
      currency: _fields.currency.value.code,
      acceptedPaymentMethods: _fields.acceptedPaymentMethodsFor(
        stripeConfigured: stripeConfigured,
      ),
      negotiable: _fields.negotiable.value,
      refusedTypes: _fields.refusedTypes.value.toList(),
      description: _fields.descriptionCtrl.text.trim().isEmpty
          ? null
          : _fields.descriptionCtrl.text.trim(),
      pickupAddress: _fields.pickupAddress.value,
      deliveryAddress: _fields.deliveryAddress.value,
      departureTime: _wire(_fields.departureTime.value),
      arrivalTime: _wire(_fields.arrivalTime.value),
      handoverLeadDays: _handoverLeadDays.value,
    );
    return template.toJson();
  }

  void _submit(BuildContext context) {
    _submitted = true;
    final data = _buildPayload(context);
    final bloc = context.read<TripTemplateBloc>();
    if (_isEditing) {
      bloc.add(TripTemplateUpdated(widget.template!.id, data));
    } else {
      bloc.add(TripTemplateCreated(data));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Recopie `state.availableKg` (écrit par `CapacityControl`, dans
    // `LieuxCapaciteStep` étape 1) dans `_fields.availableKg` — même pattern
    // que le `BlocListener` de `create_trip_screen.dart` (~L1788-1797).
    // Sans lui, la capacité saisie à l'étape 1 n'atteignait jamais le
    // payload (constat #1) : `CapacityControl` n'écrit que dans le bloc,
    // `_buildPayload` ne lisait que `_fields.availableKg`.
    return BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
      listenWhen: (prev, curr) => prev.availableKg != curr.availableKg,
      listener: (context, formState) {
        final kg = formState.availableKg ?? 0.0;
        if (kg == _fields.availableKg.value) return;
        _applyingKgFromBloc = true;
        _fields.availableKg.value = kg;
        _applyingKgFromBloc = false;
      },
      child: BlocConsumer<TripTemplateBloc, TripTemplateState>(
        listener: (context, state) {
          if (_submitted && state.status == TripTemplateStatus.success) {
            final l = context.l10n;
            DonySnackbar.show(
              context,
              message: _isEditing
                  ? l.tripTemplateUpdatedMessage
                  : l.tripTemplateSavedMessage,
              type: DonySnackbarType.success,
            );
            context.pop(true);
          }
          if (state.status == TripTemplateStatus.error && state.error != null) {
            _submitted = false;
            unawaited(ErrorPresenter.show(context, state.error));
          }
        },
        builder: (context, state) {
          final isLoading = state.status == TripTemplateStatus.loading;
          // Un seul ValueListenableBuilder sur `_step` pour tout l'écran :
          // PopScope.canPop doit se recalculer au changement d'étape, pas
          // seulement au changement d'état du bloc.
          return ValueListenableBuilder<int>(
            valueListenable: _step,
            builder: (context, step, _) {
              // Un seul handler de retour, partagé par la flèche visible de
              // l'AppBar (`onBack`) et par `PopScope` (geste système / swipe
              // iOS) : sans ça, `DonyAppBarBackButton` appelle
              // `context.pop()` directement sans consulter `canPop` et fait
              // quitter l'écran au lieu de reculer d'une étape (cf.
              // `create_trip_screen.dart`, même pattern avec
              // `_handleExitRequest`).
              void handleBack() {
                if (step == 0) {
                  context.pop();
                } else {
                  _step.value = step - 1;
                }
              }

              final l = context.l10n;
              return PopScope(
                canPop: step == 0,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) {
                    handleBack();
                  }
                },
                child: DonyPageScaffold(
                  title: _isEditing
                      ? l.tripTemplateEditTitle
                      : l.tripTemplateNewLabel,
                  onBack: handleBack,
                  stickyBottom: ValueListenableBuilder<bool>(
                    valueListenable: _canContinue,
                    builder: (context, canContinue, _) {
                      final enabled = canContinue && !isLoading;
                      return DonyButton(
                        label: step < 2
                            ? l.commonContinue
                            : l.tripTemplateSaveButton,
                        onPressed: enabled
                            ? (step < 2
                                  ? () => _step.value = step + 1
                                  : () => _submit(context))
                            : null,
                        isLoading: isLoading,
                      );
                    },
                  ),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CaStepperHeader(
                        currentStep: step,
                        totalSteps: _totalSteps,
                      ),
                      const SizedBox(height: DonySpacing.xxl),
                      ...switch (step) {
                        0 => _buildStep0(context),
                        1 => _buildStep1(),
                        _ => _buildStep2(),
                      },
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildStep0(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return [
      // ── NOM DU MODÈLE ───────────────────────────────────────────
      _SectionLabel(
        label: l.tripTemplateNameSectionLabel,
        iconAsset: 'bookmark',
      ),
      const SizedBox(height: DonySpacing.sm),
      DonyTextField(
        controller: _labelCtrl,
        label: l.tripTemplateNameFieldLabel,
        hint: l.tripTemplateNameFieldHint,
        prefixWidget: DonyIcon('tag', size: 20, color: cs.onSurfaceVariant),
      ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03),
      const SizedBox(height: DonySpacing.xxl),

      // ── TRAJET ──────────────────────────────────────────────────
      _SectionLabel(
        label: l.tripTemplateTripSectionLabel,
        iconAsset: 'plane-takeoff',
      ),
      const SizedBox(height: DonySpacing.sm),
      ListenableBuilder(
        listenable: Listenable.merge([
          _fields.departureCity,
          _fields.arrivalCity,
        ]),
        builder: (context, _) => CityCorridorFields(
          departureValue: _fields.departureCity.value,
          arrivalValue: _fields.arrivalCity.value,
          departureFieldKey: const Key('trip-template-departure-city'),
          arrivalFieldKey: const Key('trip-template-arrival-city'),
          requiredLabels: true,
          onDepartureSelected: (city) {
            _fields.departureCity.value = city.name;
            _fields.departureCountryCode.value = city.countryCode;
          },
          onArrivalSelected: (city) {
            _fields.arrivalCity.value = city.name;
            _fields.arrivalCountryCode.value = city.countryCode;
          },
          onDepartureCleared: () {
            _fields.departureCity.value = null;
            _fields.departureCountryCode.value = null;
          },
          onArrivalCleared: () {
            _fields.arrivalCity.value = null;
            _fields.arrivalCountryCode.value = null;
          },
          onSwap: () {
            final city = _fields.departureCity.value;
            _fields.departureCity.value = _fields.arrivalCity.value;
            _fields.arrivalCity.value = city;
            final code = _fields.departureCountryCode.value;
            _fields.departureCountryCode.value =
                _fields.arrivalCountryCode.value;
            _fields.arrivalCountryCode.value = code;
          },
        ),
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── MODE DE TRANSPORT ───────────────────────────────────────
      _SectionLabel(
        label: l.tripTemplateTransportSectionLabel,
        iconAsset: 'route',
      ),
      const SizedBox(height: DonySpacing.sm),
      ListenableBuilder(
        listenable: _fields.transportMode,
        builder: (context, _) => Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final mode in TransportMode.values)
              DonyChip(
                label: mode.label(context.l10n),
                icon: mode.icon,
                selected: _fields.transportMode.value == mode,
                onTap: () => _fields.transportMode.value = mode,
              ),
          ],
        ),
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── HORAIRES ─────────────────────────────────────────────────
      _SectionLabel(
        label: l.tripTemplateScheduleSectionLabel,
        iconAsset: 'clock',
      ),
      const SizedBox(height: DonySpacing.sm),
      _TimeRow(
        icon: 'plane-takeoff',
        label: l.tripTemplateDepartureTimeFieldLabel,
        shortLabel: l.tripTemplateDepartureShortLabel,
        time: _fields.departureTime,
      ),
      const SizedBox(height: DonySpacing.sm),
      _TimeRow(
        icon: 'plane-landing',
        label: l.tripTemplateArrivalTimeFieldLabel,
        shortLabel: l.tripTemplateArrivalShortLabel,
        time: _fields.arrivalTime,
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── DÉLAI DE REMISE ─────────────────────────────────────────
      _SectionLabel(
        label: l.tripTemplateHandoverDeadlineSectionLabel,
        iconAsset: 'timer',
      ),
      const SizedBox(height: DonySpacing.sm),
      Text(
        l.tripTemplateHandoverDeadlineHint,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: DonySpacing.sm),
      ValueListenableBuilder<int?>(
        valueListenable: _handoverLeadDays,
        builder: (context, selected, _) => Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final choice in _handoverChoices(l))
              DonyChip(
                label: choice.$2,
                selected: selected == choice.$1,
                onTap: () => _handoverLeadDays.value = choice.$1,
              ),
          ],
        ),
      ),
      const SizedBox(height: DonySpacing.md),
    ];
  }

  /// Lieux & capacité : adresses de remise/livraison optionnelles (jamais
  /// d'erreur affichée pour un modèle), capacité pilotée par `CapacityControl`
  /// (autonome, lit/écrit `AnnouncementFormBloc` directement).
  List<Widget> _buildStep1() => [
    LieuxCapaciteStep(
      initialPickupAddress: _fields.pickupAddress.value,
      initialDeliveryAddress: _fields.deliveryAddress.value,
      onPickupSaved: (v) => _fields.pickupAddress.value = v,
      onDeliverySaved: (v) => _fields.deliveryAddress.value = v,
      onPickupChanged: (v) => _fields.pickupAddress.value = v,
      onDeliveryChanged: (v) => _fields.deliveryAddress.value = v,
    ),
  ];

  /// Prix & conditions : bandeau devise + étape partagée avec la création de
  /// trajet, elle-même consciente du mode de tarification et de la bascule
  /// mobile money via `AnnouncementFormBloc` / `MobileMoneyAccountBloc`.
  List<Widget> _buildStep2() => [
    CurrencySelectionBanner(currencyNotifier: _fields.currency),
    const SizedBox(height: DonySpacing.lg),
    BlocBuilder<MobileMoneyAccountBloc, MobileMoneyAccountState>(
      builder: (context, mobileMoneyState) =>
          ValueListenableBuilder<SupportedCurrency>(
            valueListenable: _fields.currency,
            builder: (context, currency, _) => PrixConditionsStep(
              currency: currency,
              priceOptionNotifier: _fields.priceOption,
              customPriceNotifier: _fields.customPrice,
              availableKgNotifier: _fields.availableKg,
              cashEnabledNotifier: _fields.cashEnabled,
              kgPriceEnabledNotifier: _fields.kgPriceEnabled,
              mobileMoneyEnabledNotifier: _fields.mobileMoneyEnabled,
              currencyNotifier: _fields.currency,
              mobileMoneyAccountActive: mobileMoneyAccountActiveFrom(
                mobileMoneyState,
              ),
              negotiableNotifier: _fields.negotiable,
              selectedContentNotifier: _fields.selectedContent,
              customAcceptedNotifier: _fields.customAccepted,
              refusedTypesNotifier: _fields.refusedTypes,
              catalogLabelsNotifier: _fields.catalogLabels,
              descriptionCtrl: _fields.descriptionCtrl,
              customAcceptedCtrl: _fields.customAcceptedCtrl,
              refusedCtrl: _fields.refusedCtrl,
              customPriceCtrl: _fields.customPriceCtrl,
            ),
          ),
    ),
  ];
}

/// Rangée d'heure éditable (départ ou arrivée) — reprend le rendu de
/// l'ancienne section HEURE D'ARRIVÉE : un seul texte qui bascule entre le
/// placeholder et la valeur formatée (préfixée du libellé court, ex.
/// « Départ · 22:00 » — le libellé reste visible une fois l'heure posée),
/// avec un bouton d'effacement quand une heure est choisie.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.shortLabel,
    required this.time,
  });

  final String icon;

  /// Libellé complet, utilisé au placeholder et dans l'annonce d'accessibilité.
  final String label;

  /// Libellé court affiché en préfixe une fois l'heure posée (« Départ »,
  /// « Arrivée »).
  final String shortLabel;
  final ValueNotifier<TimeOfDay?> time;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return ValueListenableBuilder<TimeOfDay?>(
      valueListenable: time,
      builder: (context, value, _) {
        final heure = value == null
            ? null
            : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
        return Semantics(
          label: heure == null ? null : '$label, $heure',
          child: GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: value ?? const TimeOfDay(hour: 12, minute: 0),
              );
              if (picked != null) time.value = picked;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.md,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border.all(color: cs.outline),
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Row(
                children: [
                  DonyIcon(icon, color: cs.primary, size: 20),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Text(
                      heure == null
                          ? l.tripTemplateOptionalSuffix(label)
                          : '$shortLabel · $heure',
                      style: tt.bodyMedium?.copyWith(
                        color: heure == null
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                        fontWeight: heure == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (heure != null)
                    Semantics(
                      button: true,
                      container: true,
                      excludeSemantics: true,
                      label: l.tripTemplateClearFieldSemantic(label),
                      child: GestureDetector(
                        onTap: () => time.value = null,
                        child: DonyIcon(
                          'x',
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.iconAsset});

  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        DonyIcon(iconAsset, size: 18, color: cs.primary),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
