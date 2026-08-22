import 'dart:async';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/currency_selector.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_preview_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_create_announcement_constants.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart'
    show NegotiationThreadStatus;
import 'package:dony/features/package_request/presentation/widgets/payment_capability_block_sheets.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CreateTripArgs {
  final AnnouncementModel? announcement;
  final LockedTripContext? lockContext;
  final NegotiationBloc? negotiationBloc;
  final bool lockCorridorAndDate;

  const CreateTripArgs({
    this.announcement,
    this.lockContext,
    this.negotiationBloc,
    this.lockCorridorAndDate = false,
  });
}

class CreateTripScreen extends StatefulWidget {
  final CreateTripArgs? args;

  const CreateTripScreen({super.key, this.args});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  late final ValueNotifier<bool> _canSubmitNotifier;
  late final ValueNotifier<int> _currentStepNotifier;
  late final ValueNotifier<bool> _canContinueNotifier;
  late final ValueNotifier<bool> _canContinueStep1Notifier;
  late final ValueNotifier<TimeOfDay?> _departureTimeNotifier;
  void Function({bool saveAsDraft})? _submit;

  /// Devise de l'annonce. En création, choisie par l'utilisateur (défaut :
  /// devise du portefeuille) ; en édition ou trajet dédié, figée sur la
  /// devise déjà portée par l'annonce/le verrou — elle ne se change plus une
  /// fois l'annonce publiée.
  late final ValueNotifier<SupportedCurrency> _currencyNotifier =
      ValueNotifier<SupportedCurrency>(_initialCurrency());

  SupportedCurrency _initialCurrency() {
    final announcement = widget.args?.announcement;
    if (announcement != null) {
      return SupportedCurrency.fromCodeOrDefault(announcement.currency);
    }
    return ActiveCurrency.current ?? SupportedCurrency.eur;
  }

  /// Vrai dès que l'utilisateur a modifié un champ depuis l'ouverture.
  ///
  /// Piloté par `_TripFormContentState`, qui n'arme ses listeners qu'après le
  /// pré-remplissage : ouvrir un trajet en modification ne rend donc pas
  /// l'écran « sale ». Sert uniquement à décider si la sortie doit être
  /// confirmée.
  final ValueNotifier<bool> _isDirtyNotifier = ValueNotifier<bool>(false);

  /// Vrai pendant l'affichage du dialogue de confirmation, pour ne pas en
  /// empiler deux si l'utilisateur insiste sur le retour système.
  bool _confirmingExit = false;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    _canSubmitNotifier = ValueNotifier<bool>(
      args?.announcement?.transportMode != null || args?.lockContext != null,
    );
    _currentStepNotifier = ValueNotifier<int>(0);
    _departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
    _canContinueNotifier = ValueNotifier<bool>(
      args?.announcement != null || args?.lockContext != null,
    );
    _canContinueStep1Notifier = ValueNotifier<bool>(
      args?.announcement?.pickupAddress != null &&
          args?.announcement?.deliveryAddress != null,
    );

    final isCreation = args?.announcement == null && args?.lockContext == null;
    if (isCreation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            getIt<AnalyticsService>().logEvent(
              AnalyticsEvents.tripCreateStarted,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _canSubmitNotifier.dispose();
    _currentStepNotifier.dispose();
    _departureTimeNotifier.dispose();
    _canContinueNotifier.dispose();
    _canContinueStep1Notifier.dispose();
    _isDirtyNotifier.dispose();
    _currencyNotifier.dispose();
    super.dispose();
  }

  /// Sortie demandée (croix de l'app bar ou retour système).
  ///
  /// Sans saisie en cours on sort directement : imposer une confirmation à
  /// quelqu'un qui n'a fait qu'ouvrir l'écran serait une nuisance.
  Future<void> _handleExitRequest() async {
    if (!_isDirtyNotifier.value) {
      _leave();
      return;
    }
    if (_confirmingExit) return;
    _confirmingExit = true;
    final confirmed = await DonyDialog.confirmDiscard(context);
    _confirmingExit = false;
    if (!mounted || confirmed != true) return;
    _leave();
  }

  /// Quitte l'écran. `pop` quand il y a une page dessous, repli sur l'accueil
  /// sinon (deep link direct vers /trips/create).
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final isLocked = args?.lockContext != null;
    final isEdit = args?.announcement != null;

    final providers = <BlocProvider>[
      BlocProvider<AnnouncementBloc>(create: (_) => getIt<AnnouncementBloc>()),
      BlocProvider<CommissionMethodBloc>(
        create: (_) => getIt<CommissionMethodBloc>(),
      ),
      BlocProvider<AnnouncementFormBloc>(
        create: (_) => getIt<AnnouncementFormBloc>(),
      ),
      BlocProvider<TripTemplateBloc>(
        create: (_) =>
            getIt<TripTemplateBloc>()..add(const TripTemplateLoaded()),
      ),
      BlocProvider<StripeAccountBloc>(
        create: (_) => getIt<StripeAccountBloc>(),
      ),
      if (args?.negotiationBloc != null)
        BlocProvider<NegotiationBloc>.value(value: args!.negotiationBloc!),
    ];

    return MultiBlocProvider(
      providers: providers,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isDirtyNotifier,
        builder: (context, isDirty, child) => PopScope(
          // canPop false tant qu'il y a de la saisie : le retour système et le
          // swipe iOS sont alors interceptés au lieu de fermer l'écran.
          canPop: !isDirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_handleExitRequest());
          },
          child: child!,
        ),
        child: Scaffold(
          appBar: AppBar(
            leading: DonyAppBarBackButton(
              leadingIconAsset: 'x',
              onBack: () => unawaited(_handleExitRequest()),
            ),
            title: Text(
              isLocked
                  ? 'Créer le trajet pour cette demande'
                  : (isEdit ? 'Modifier le trajet' : 'Publier un trajet'),
            ),
          ),
          resizeToAvoidBottomInset: true,
          // Bouton sticky dans `body` (pas `bottomNavigationBar`) : Flutter ne
          // remonte pas fiablement `bottomNavigationBar` au-dessus du clavier,
          // ce qui le cachait derrière sur PrixConditionsStep (champs prix /
          // conditions). Même fix que phone_auth_screen.dart.
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(DonySpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ContextualTutorialCard(
                        context: TutorialContext.tripPublish,
                      ),
                      const SizedBox(height: DonySpacing.base),
                      if (!isEdit && !isLocked) ...[
                        _CurrencySelectionBanner(
                          currencyNotifier: _currencyNotifier,
                        ),
                        const SizedBox(height: DonySpacing.base),
                      ],
                      _TripFormContent(
                        announcement: args?.announcement,
                        lockContext: args?.lockContext,
                        lockCorridorAndDate: args?.lockCorridorAndDate ?? false,
                        canSubmitNotifier: _canSubmitNotifier,
                        canContinueNotifier: _canContinueNotifier,
                        canContinueStep1Notifier: _canContinueStep1Notifier,
                        currentStepNotifier: _currentStepNotifier,
                        departureTimeNotifier: _departureTimeNotifier,
                        currencyNotifier: _currencyNotifier,
                        onSubmitReady: (fn) => _submit = fn,
                        dirtyNotifier: _isDirtyNotifier,
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.sm,
                  ),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      _canSubmitNotifier,
                      _currentStepNotifier,
                      _canContinueNotifier,
                      _canContinueStep1Notifier,
                    ]),
                    builder: (ctx, _) {
                      final step = _currentStepNotifier.value;
                      final canSubmit = _canSubmitNotifier.value;
                      final canContinue = _canContinueNotifier.value;
                      final canContinueStep1 = _canContinueStep1Notifier.value;

                      // ── Étapes 0 et 1 : Continuer (+ Retour si step > 0) ──
                      if (step < 2) {
                        return Row(
                          children: [
                            if (step > 0) ...[
                              Expanded(
                                child: DonyButton(
                                  label: 'Retour',
                                  variant: DonyButtonVariant.secondary,
                                  icon: DonyIcons.back,
                                  onPressed: () =>
                                      _currentStepNotifier.value = step - 1,
                                ),
                              ),
                              const SizedBox(width: DonySpacing.sm),
                            ],
                            Expanded(
                              child: DonyButton(
                                label: 'Continuer',
                                iconRight: DonyIcons.arrowRight,
                                onPressed:
                                    ((step == 0 && !canContinue) ||
                                        (step == 1 && !canContinueStep1))
                                    ? null
                                    : () =>
                                          _currentStepNotifier.value = step + 1,
                              ),
                            ),
                          ],
                        );
                      }

                      // ── Étape 2 — Trajet dédié : Confirmer ──
                      if (isLocked) {
                        return BlocBuilder<NegotiationBloc, NegotiationState>(
                          builder: (ctx, state) {
                            final isLoading =
                                state is NegotiationLoading ||
                                state is NegotiationActionInProgress;
                            return Row(
                              children: [
                                Expanded(
                                  child: DonyButton(
                                    label: 'Retour',
                                    variant: DonyButtonVariant.secondary,
                                    icon: DonyIcons.back,
                                    onPressed: () =>
                                        _currentStepNotifier.value = step - 1,
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: DonyButton(
                                    key: const Key(
                                      'create-dedicated-trip-submit',
                                    ),
                                    label: 'Confirmer le trajet',
                                    isLoading: isLoading,
                                    onPressed: (canSubmit && !isLoading)
                                        ? () => _submit?.call()
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }

                      // ── Étape 2 — Mode édition : Enregistrer ──
                      if (isEdit) {
                        return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                          builder: (ctx, state) {
                            final isLoading = state is AnnouncementLoading;
                            return Row(
                              children: [
                                Expanded(
                                  child: DonyButton(
                                    label: 'Retour',
                                    variant: DonyButtonVariant.secondary,
                                    icon: DonyIcons.back,
                                    onPressed: () =>
                                        _currentStepNotifier.value = step - 1,
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: DonyButton(
                                    key: const Key(
                                      'create-announcement-submit',
                                    ),
                                    label: 'Enregistrer',
                                    isLoading: isLoading,
                                    onPressed: (canSubmit && !isLoading)
                                        ? () => _submit?.call()
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }

                      // ── Étape 2 — Mode création : Aperçu ──
                      // Publiable sans Stripe configuré (cash-only) — Stripe n'est
                      // plus une condition bloquante ici, seule la section paiement
                      // (PrixConditionsStep) reflète le verrouillage de la carte.
                      return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                        builder: (ctx, annState) {
                          final isLoading = annState is AnnouncementLoading;
                          return BlocBuilder<
                            AnnouncementFormBloc,
                            AnnouncementFormState
                          >(
                            builder: (ctx2, formState) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: DonyButton(
                                      label: 'Retour',
                                      variant: DonyButtonVariant.secondary,
                                      icon: DonyIcons.back,
                                      onPressed: () =>
                                          _currentStepNotifier.value = step - 1,
                                    ),
                                  ),
                                  const SizedBox(width: DonySpacing.sm),
                                  Expanded(
                                    child: DonyButton(
                                      key: const Key(
                                        'create-announcement-preview',
                                      ),
                                      label: 'Aperçu',
                                      iconRight: DonyIcons.arrowRight,
                                      isLoading: isLoading,
                                      onPressed: (canSubmit && !isLoading)
                                          ? () {
                                              AnnouncementPreviewSheet.show(
                                                ctx2,
                                                formState: ctx2
                                                    .read<
                                                      AnnouncementFormBloc
                                                    >()
                                                    .state,
                                                onConfirm: () {
                                                  // Intentional: closes the preview sheet,
                                                  // not the CreateTripScreen.
                                                  Navigator.of(
                                                    ctx2,
                                                    rootNavigator: true,
                                                  ).pop();
                                                  _submit?.call();
                                                },
                                                onSaveDraft: () {
                                                  // Même fermeture du sheet que onConfirm.
                                                  Navigator.of(
                                                    ctx2,
                                                    rootNavigator: true,
                                                  ).pop();
                                                  _submit?.call(
                                                    saveAsDraft: true,
                                                  );
                                                },
                                                isSubmitting: isLoading,
                                                departureTime:
                                                    _departureTimeNotifier
                                                        .value,
                                                currency:
                                                    _currencyNotifier.value,
                                              );
                                            }
                                          : null,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Content widget ───────────────────────────────────────────────────────────

class _TripFormContent extends StatefulWidget {
  final AnnouncementModel? announcement;
  final LockedTripContext? lockContext;

  /// Édition d'un trajet à lier à une négo : corridor + date verrouillés, et on
  /// reste sur l'écran de liaison au succès (pas de redirection /announcements).
  final bool lockCorridorAndDate;
  final ValueNotifier<bool>? canSubmitNotifier;
  final ValueNotifier<bool>? canContinueNotifier;
  final ValueNotifier<bool>? canContinueStep1Notifier;
  final ValueNotifier<int>? currentStepNotifier;

  /// Passe à true dès la première modification utilisateur. Le parent s'en
  /// sert pour décider si quitter l'écran doit être confirmé.
  final ValueNotifier<bool>? dirtyNotifier;
  final ValueNotifier<TimeOfDay?>? departureTimeNotifier;

  /// Devise de l'annonce, portée par le parent (cf. `_CreateTripScreenState`).
  /// Choisie par l'utilisateur en création, figée en édition/trajet dédié.
  final ValueNotifier<SupportedCurrency> currencyNotifier;
  final void Function(void Function({bool saveAsDraft}))? onSubmitReady;

  const _TripFormContent({
    this.announcement,
    this.lockContext,
    this.lockCorridorAndDate = false,
    this.canSubmitNotifier,
    this.canContinueNotifier,
    this.canContinueStep1Notifier,
    this.currentStepNotifier,
    this.dirtyNotifier,
    this.departureTimeNotifier,
    required this.currencyNotifier,
    this.onSubmitReady,
  });

  @override
  State<_TripFormContent> createState() => _TripFormContentState();
}

class _TripFormContentState extends State<_TripFormContent> {
  final _formKey = GlobalKey<FormState>();

  /// The last `NegotiationStartWithDedicatedTripRequested` dispatched by
  /// `_submit()` — brand-new offer with no existing thread yet
  /// (`lockContext.threadId == null`). Kept to tell that flow apart from the
  /// existing-thread one when the shared `NegotiationBloc` reports success:
  /// the two pop with different results and different messages.
  NegotiationStartWithDedicatedTripRequested? _lastStartWithDedicatedTripEvent;

  final _departureCityNotifier = ValueNotifier<String?>(null);
  final _arrivalCityNotifier = ValueNotifier<String?>(null);
  // Code pays ISO-2 capturé lors de la sélection ville. Synchronisé vers le
  // form bloc via _syncCityToFormBloc et lu au submit depuis l'état du bloc.
  final _departureCountryCodeNotifier = ValueNotifier<String?>(null);
  final _arrivalCountryCodeNotifier = ValueNotifier<String?>(null);
  final _departureDateNotifier = ValueNotifier<DateTime?>(null);
  final _departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final _arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);

  /// Date limite de dépôt : jour seul choisi par le voyageur, converti en
  /// instant à l'envoi (cf. [_resolveHandoverDeadline]).
  final _handoverDeadlineNotifier = ValueNotifier<DateTime?>(null);
  final _pickupAddressNotifier = ValueNotifier<AddressData?>(null);
  final _deliveryAddressNotifier = ValueNotifier<AddressData?>(null);
  AddressData? get _pickupAddress => _pickupAddressNotifier.value;
  AddressData? get _deliveryAddress => _deliveryAddressNotifier.value;
  final _availableKgNotifier = ValueNotifier<double>(15);
  final _priceOptionNotifier = ValueNotifier<int>(-1); // -1 = aucune sélection
  final _transportModeNotifier = ValueNotifier<TransportMode?>(null);

  // ── Erreurs de champs obligatoires ──────────────────────────────────────────
  // Les champs manquants ne passent en rouge qu'après une première interaction
  // de l'utilisateur avec l'étape : un formulaire vierge reste neutre.
  bool _step0Touched = false;
  bool _step1Touched = false;
  final _step0ErrorsNotifier = ValueNotifier<Set<_Step0Field>>(
    const <_Step0Field>{},
  );
  final _step1ErrorsNotifier = ValueNotifier<Set<_Step1Field>>(
    const <_Step1Field>{},
  );

  final _selectedContentNotifier = ValueNotifier<Set<String>>({
    'Vêtements & tissus',
    'Médicaments traditionnels',
    'Documents & administratif',
  });
  final _customAcceptedNotifier = ValueNotifier<Set<String>>({});
  // Catalogue de types de contenu — seedé synchrone avec le catalogue
  // embarqué (fallbackCatalog), puis remplacé par le catalogue live du
  // repository dès qu'il répond (repli automatique hors ligne intégré).
  final _catalogLabelsNotifier = ValueNotifier<List<String>>(
    fallbackCatalog.map((c) => c.label).toList(),
  );
  final _refusedTypesNotifier = ValueNotifier<Set<String>>({});
  final _cashEnabledNotifier = ValueNotifier<bool>(false);

  /// Le voyageur ouvre son trajet aux propositions de prix des expéditeurs.
  final _negotiableNotifier = ValueNotifier<bool>(false);
  late final ValueNotifier<bool> _kgPriceEnabledNotifier;
  final _descriptionCtrl = TextEditingController();
  final _customAcceptedCtrl = TextEditingController();
  final _refusedCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _customPriceNotifier = ValueNotifier<double>(6.0);

  bool get _isEdit => widget.announcement != null;
  bool get _isLocked => widget.lockContext != null;

  /// Devise de l'annonce — suit le sélecteur du parent (`_CreateTripScreenState`),
  /// pas la devise active du profil : une annonce se publie désormais dans la
  /// devise choisie à la création, potentiellement distincte du portefeuille.
  SupportedCurrency get _currency => widget.currencyNotifier.value;
  bool get _isCustomPrice => _priceOptionNotifier.value == kPriceOptions.length;
  double get _pricePerKg => _isCustomPrice
      ? _customPriceNotifier.value
      : kPriceOptions[_priceOptionNotifier.value.clamp(
          0,
          kPriceOptions.length - 1,
        )];

  // Vrai si le prix est correctement renseigné :
  // — mode verrouillé → prix fixé par la demande, toujours valide
  // — kg toggle OFF (mode grille) → tarification via la grille, toujours valide
  // — aucun choix effectué (idx == -1) → invalide
  // — chip preset sélectionnée → valide
  // — "Autre prix" sélectionné → le champ doit contenir un nombre > 0, et ne
  //   pas dépasser le plafond de la devise DE L'ANNONCE (pas celle du
  //   profil) : changer de devise dans le sélecteur fait donc suivre cette
  //   borne, sans quoi un montant valide en XOF resterait bloqué au plafond
  //   (bien plus bas) de l'euro, ou l'inverse laisserait passer un montant
  //   que le serveur refuserait.
  bool get _isPriceValid {
    if (_isLocked) return true;
    if (!_kgPriceEnabledNotifier.value) return true;
    final idx = _priceOptionNotifier.value;
    if (idx == -1) return false;
    if (!_isCustomPrice) return true;
    final parsed = double.tryParse(_customPriceCtrl.text.replaceAll(',', '.'));
    return parsed != null && parsed > 0 && parsed <= maxUnitPriceFor(_currency);
  }

  Future<void> _loadCatalog() async {
    final categories = await getIt<IContentCategoryRepository>()
        .getCategories();
    if (!mounted) return;
    _catalogLabelsNotifier.value = categories.map((c) => c.label).toList();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommissionMethodBloc>().add(
          CommissionMethodLoadRequested(),
        );
      }
    });
    if (_isLocked) {
      final ctx = widget.lockContext!;
      _departureCityNotifier.value = ctx.departureCity;
      _arrivalCityNotifier.value = ctx.arrivalCity;
      _departureDateNotifier.value = ctx.desiredDate;
      _availableKgNotifier.value = ctx.weightKg;
      _transportModeNotifier.value = ctx.transportMode;
    }
    if (_isEdit) {
      final a = widget.announcement!;
      _departureCityNotifier.value = a.departureCity;
      _arrivalCityNotifier.value = a.arrivalCity;
      _departureCountryCodeNotifier.value = a.departureCountryCode;
      _arrivalCountryCodeNotifier.value = a.arrivalCountryCode;
      _departureDateNotifier.value = a.departureDate;
      _handoverDeadlineNotifier.value = widget.announcement?.handoverDeadline;
      _availableKgNotifier.value = a.availableKg;

      if (a.departureTime != null) {
        final parts = a.departureTime!.split(':');
        _departureTimeNotifier.value = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      if (a.arrivalTime != null) {
        final parts = a.arrivalTime!.split(':');
        _arrivalTimeNotifier.value = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      _pickupAddressNotifier.value = a.pickupAddress;
      _deliveryAddressNotifier.value = a.deliveryAddress;
      _transportModeNotifier.value = a.transportMode;

      if (a.description != null) {
        _descriptionCtrl.text = a.description!;
      }

      if (a.acceptedContentTypes != null) {
        final presets = Set<String>.from(
          a.acceptedContentTypes!.where(_catalogLabelsNotifier.value.contains),
        );
        final custom = Set<String>.from(
          a.acceptedContentTypes!.where(
            (t) => !_catalogLabelsNotifier.value.contains(t),
          ),
        );
        _selectedContentNotifier.value = presets;
        _customAcceptedNotifier.value = custom;
      }
      if (a.refusedTypes != null) {
        _refusedTypesNotifier.value = Set<String>.from(a.refusedTypes!);
      }

      _cashEnabledNotifier.value = a.acceptedPaymentMethods.contains(
        BidPaymentMethod.cash,
      );

      // Sans ce report, rouvrir un trajet ouvert aux propositions pour le
      // modifier le refermerait en silence à l'enregistrement.
      _negotiableNotifier.value = a.negotiable;

      // pricePerKg est le net voyageur : absent uniquement pour un lecteur
      // anonyme, jamais pour le propriétaire du trajet qui l'édite ici. On
      // laisse les notifiers de prix à leur valeur initiale si, malgré tout,
      // il manquait.
      final price = a.pricePerKg;
      if (price != null) {
        final presetIdx = kPriceOptions.indexOf(price);
        if (presetIdx != -1) {
          _priceOptionNotifier.value = presetIdx;
        } else {
          // Prix custom — sélectionner "Autre" et pré-remplir le champ
          _priceOptionNotifier.value = kPriceOptions.length;
          _customPriceNotifier.value = price;
          _customPriceCtrl.text = price.toStringAsFixed(0);
        }
      }

      // Sync capacityUnit et pricingMode vers le BLoC (requiert context → postFrame)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final formBloc = context.read<AnnouncementFormBloc>();

        final unit = switch (a.capacityUnit) {
          'KG_FREE' => CapacityUnit.kgFree,
          'SUITCASE_32KG' => CapacityUnit.suitcase32kg,
          'KG_EXACT' => CapacityUnit.custom,
          _ => CapacityUnit.suitcase23kg,
        };
        formBloc.add(CapacityUnitChanged(unit));

        final mode = a.pricingMode == 'MIXED'
            ? PricingMode.mixed
            : PricingMode.kg;
        formBloc.add(AnnouncementPricingModeSetRequested(mode));

        // Seed le prix dans le form bloc depuis les notifiers pré-remplis : le
        // listener ne s'est pas déclenché (valeurs posées avant son attache).
        // Indispensable quand la section prix est masquée (lockPrice) — sinon
        // le submit enverrait pricePerKg = 0 et écraserait le prix du trajet.
        _syncPriceToFormBloc();

        // Seed la ville + le code pays dans le form bloc depuis les notifiers
        // pré-remplis : le listener _syncCityToFormBloc n'a pas pu se déclencher
        // (valeurs posées avant son attache). Sans ce sync explicite, éditer une
        // annonce SANS re-sélectionner la ville submitterait
        // departureCountryCode/arrivalCountryCode = null. Edit-mode uniquement.
        _syncCityToFormBloc();
      });
    }
    widget.onSubmitReady?.call(_submit);
    _kgPriceEnabledNotifier = ValueNotifier<bool>(true); // KG = ON par défaut
    _kgPriceEnabledNotifier.addListener(_onKgToggleChanged);
    _kgPriceEnabledNotifier.addListener(_syncCanSubmit);
    _transportModeNotifier.addListener(_syncCanSubmit);
    _priceOptionNotifier.addListener(_syncCanSubmit);
    _customPriceCtrl.addListener(_syncCanSubmit);
    // Un prix custom valide dans une devise peut dépasser le plafond d'une
    // autre (cf. _isPriceValid) : changer de devise doit donc réévaluer
    // canSubmit sans que l'utilisateur retouche le champ prix.
    widget.currencyNotifier.addListener(_syncCanSubmit);
    // Avion sélectionné par défaut en mode création
    if (!_isEdit && !_isLocked) {
      _transportModeNotifier.value = TransportMode.plane;
    }
    _syncCanSubmit(); // état initial — transport + prix

    // Désactivation du bouton Continuer tant que les 3 champs obligatoires
    // de l'étape 0 ne sont pas renseignés.
    _departureCityNotifier.addListener(_updateCanContinue);
    _arrivalCityNotifier.addListener(_updateCanContinue);
    _departureDateNotifier.addListener(_updateCanContinue);
    _departureTimeNotifier.addListener(_updateCanContinue);
    _transportModeNotifier.addListener(_updateCanContinue);
    _handoverDeadlineNotifier.addListener(_updateCanContinue);
    _updateCanContinue(); // état initial (pré-remplissage en mode édition)

    // Armé APRÈS le calcul initial : la pré-sélection automatique du mode
    // avion et le pré-remplissage en édition ne comptent pas comme une
    // interaction, donc n'allument aucun message d'erreur à l'ouverture.
    _departureCityNotifier.addListener(_markStep0Touched);
    _arrivalCityNotifier.addListener(_markStep0Touched);
    _departureDateNotifier.addListener(_markStep0Touched);
    _departureTimeNotifier.addListener(_markStep0Touched);
    // Facultative, mais y toucher reste une interaction avec l'étape.
    _arrivalTimeNotifier.addListener(_markStep0Touched);
    _transportModeNotifier.addListener(_markStep0Touched);
    _handoverDeadlineNotifier.addListener(_markStep0Touched);

    // L'étape 1 n'a que deux champs, et on n'y arrive qu'en ayant complété
    // l'étape 0 : y entrer vaut engagement, on annonce donc tout de suite ce
    // qu'elle attend plutôt que de laisser un bouton gris sans explication.
    widget.currentStepNotifier?.addListener(_markStep1TouchedOnEntry);
    _updateCanContinueStep1();

    // Détection de saisie en cours. La référence n'est PAS prise ici : elle
    // l'est après deux post-frames (_captureInitialSignature), et le garde
    // `_initialFormSignature == null` de _markDirty neutralise l'intervalle.
    for (final l in _userEditableListenables) {
      l.addListener(_markDirty);
    }
    _captureInitialSignature();

    // Sync form fields to AnnouncementFormBloc for preview and validation
    _departureCityNotifier.addListener(_syncCityToFormBloc);
    _arrivalCityNotifier.addListener(_syncCityToFormBloc);
    _departureDateNotifier.addListener(_syncDateToFormBloc);
    _priceOptionNotifier.addListener(_syncPriceToFormBloc);
    _customPriceNotifier.addListener(_syncPriceToFormBloc);
    _availableKgNotifier.addListener(_syncKgToFormBloc);
    _descriptionCtrl.addListener(_syncDescriptionToFormBloc);
    _transportModeNotifier.addListener(_syncTransportModeToFormBloc);
    _cashEnabledNotifier.addListener(_syncCashAcceptedToFormBloc);
    _selectedContentNotifier.addListener(_syncAcceptedTypesToFormBloc);
    _customAcceptedNotifier.addListener(_syncAcceptedTypesToFormBloc);
    _refusedTypesNotifier.addListener(_syncRejectedTypesToFormBloc);
    _departureTimeNotifier.addListener(_syncDepartureTimeToParent);
  }

  /// Champs obligatoires manquants à l'étape 0, dans l'ordre d'affichage.
  ///
  /// Source de vérité unique : `_updateCanContinue()` en dérive l'état du
  /// bouton et les champs en dérivent leur `errorText`. Les deux ne peuvent
  /// donc pas diverger — c'est exactement ce qui a laissé passer l'heure de
  /// départ (listener branché, condition oubliée).
  Set<_Step0Field> get _missingStep0Fields => {
    if (_departureCityNotifier.value == null) _Step0Field.departureCity,
    if (_departureTimeNotifier.value == null) _Step0Field.departureTime,
    if (_arrivalCityNotifier.value == null) _Step0Field.arrivalCity,
    if (_departureDateNotifier.value == null) _Step0Field.departureDate,
    if (_transportModeNotifier.value == null) _Step0Field.transportMode,
    if (_handoverDeadlineNotifier.value == null) _Step0Field.handoverDeadline,
  };

  void _updateCanContinue() {
    final missing = _missingStep0Fields;
    widget.canContinueNotifier?.value =
        missing.isEmpty && _handoverDeadlineError() == null;
    _refreshStep0Errors(missing);
  }

  /// Publie les erreurs de l'étape 0 — mais seulement une fois que
  /// l'utilisateur a touché à quelque chose.
  ///
  /// Un formulaire de création vierge ne doit pas s'ouvrir tout en rouge ;
  /// `_step0Touched` n'est armé qu'après le calcul initial de `initState`
  /// (cf. `_markStep0Touched`), donc la pré-sélection automatique du mode
  /// avion ne le déclenche pas.
  void _refreshStep0Errors([Set<_Step0Field>? missing]) {
    final next = _step0Touched
        ? (missing ?? _missingStep0Fields)
        : const <_Step0Field>{};
    // `_missingStep0Fields` renvoie un Set neuf a chaque appel et Set n'a pas
    // d'operator == : sans cette comparaison de contenu, le notifier previent
    // ses auditeurs a chaque frappe meme quand rien n'a change, et reconstruit
    // TrajetStep pour rien.
    if (setEquals(_step0ErrorsNotifier.value, next)) return;
    _step0ErrorsNotifier.value = next;
  }

  /// Message du champ [f] s'il fait partie des manquants, sinon null.
  static String? _msg(Set<_Step0Field> missing, _Step0Field f) =>
      missing.contains(f) ? f.message : null;

  void _markStep0Touched() {
    if (_step0Touched) return;
    _step0Touched = true;
    _refreshStep0Errors();
  }

  /// Tout ce que l'utilisateur peut modifier dans le formulaire.
  ///
  /// `_catalogLabelsNotifier` en est volontairement absent : il est rempli par
  /// le chargement asynchrone du catalogue, pas par une action utilisateur.
  List<Listenable> get _userEditableListenables => [
    _departureCityNotifier,
    _arrivalCityNotifier,
    _departureDateNotifier,
    _departureTimeNotifier,
    _arrivalTimeNotifier,
    _handoverDeadlineNotifier,
    _pickupAddressNotifier,
    _deliveryAddressNotifier,
    _availableKgNotifier,
    _priceOptionNotifier,
    _customPriceNotifier,
    _transportModeNotifier,
    _selectedContentNotifier,
    _customAcceptedNotifier,
    _refusedTypesNotifier,
    _cashEnabledNotifier,
    _negotiableNotifier,
    _kgPriceEnabledNotifier,
    _descriptionCtrl,
    _customAcceptedCtrl,
    _refusedCtrl,
    _customPriceCtrl,
  ];

  /// Signature de l'état saisissable du formulaire.
  ///
  /// La saleté se mesure en comparant cette signature à celle prise à
  /// l'ouverture, et non en écoutant les notifications : plusieurs champs sont
  /// réécrits avec leur propre valeur au démarrage (le `BlocListener` sur
  /// `pricingMode` repositionne `_kgPriceEnabledNotifier`, et les notifiers de
  /// `Set` notifient dès qu'on leur assigne un ensemble égal mais distinct).
  /// Compter ces échos comme des modifications faisait apparaître la
  /// confirmation de sortie sur un formulaire auquel personne n'avait touché.
  ///
  /// Effet de bord souhaitable : revenir à la saisie d'origine « nettoie » le
  /// formulaire, et quitter redevient silencieux.
  String get _formSignature {
    String set(Set<String> v) => (v.toList()..sort()).join(',');
    return [
      _departureCityNotifier.value,
      _arrivalCityNotifier.value,
      _departureDateNotifier.value,
      _departureTimeNotifier.value,
      _arrivalTimeNotifier.value,
      _handoverDeadlineNotifier.value,
      _pickupAddressNotifier.value?.label,
      _deliveryAddressNotifier.value?.label,
      _availableKgNotifier.value,
      _priceOptionNotifier.value,
      _customPriceNotifier.value,
      _transportModeNotifier.value,
      _cashEnabledNotifier.value,
      _negotiableNotifier.value,
      _kgPriceEnabledNotifier.value,
      set(_selectedContentNotifier.value),
      set(_customAcceptedNotifier.value),
      set(_refusedTypesNotifier.value),
      _descriptionCtrl.text,
      _customAcceptedCtrl.text,
      _refusedCtrl.text,
      _customPriceCtrl.text,
    ].join('|');
  }

  /// Référence de comparaison. Nulle tant que la première frame n'a pas été
  /// rendue : voir `_captureInitialSignature`.
  String? _initialFormSignature;

  void _markDirty() {
    if (_initialFormSignature == null) return;
    final dirty = _formSignature != _initialFormSignature;
    if (widget.dirtyNotifier != null && widget.dirtyNotifier!.value != dirty) {
      widget.dirtyNotifier!.value = dirty;
    }
  }

  /// Reprend la référence une fois la première frame passée.
  ///
  /// Certains champs sont positionnés par l'application elle-même, pas par
  /// l'utilisateur, et seulement une fois l'arbre construit : `PrixConditionsStep`
  /// force par exemple les espèces à ON en post-frame quand Stripe n'est pas
  /// configuré. Pris à la fin de `initState`, l'instantané précède ces
  /// écritures et l'écran s'ouvrait « sale », réclamant une confirmation de
  /// sortie à quelqu'un qui n'avait rien touché.
  ///
  /// Deux post-frames sont nécessaires : le premier s'exécute avant les
  /// callbacks enregistrés pendant le build initial (ordre d'inscription),
  /// donc c'est au second que tout est réellement stabilisé. Aucune saisie
  /// utilisateur ne peut s'intercaler en deux frames.
  void _captureInitialSignature() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initialFormSignature = _formSignature;
        _markDirty();
      });
    });
  }

  void _markStep1TouchedOnEntry() {
    if (_step1Touched || widget.currentStepNotifier?.value != 1) return;
    _step1Touched = true;
    _updateCanContinueStep1();
  }

  void _updateCanContinueStep1() {
    widget.canContinueStep1Notifier?.value =
        _pickupAddress != null && _deliveryAddress != null;
    // « Touché » est arme uniquement a l'entree dans l'etape
    // (_markStep1TouchedOnEntry). L'armer aussi ici faisait s'ouvrir en rouge
    // une modification d'annonce n'ayant qu'une des deux adresses.
    final next = _step1Touched
        ? {
            if (_pickupAddress == null) _Step1Field.pickupAddress,
            if (_deliveryAddress == null) _Step1Field.deliveryAddress,
          }
        : const <_Step1Field>{};
    if (!setEquals(_step1ErrorsNotifier.value, next)) {
      _step1ErrorsNotifier.value = next;
    }
  }

  void _syncCanSubmit() {
    widget.canSubmitNotifier?.value =
        _transportModeNotifier.value != null && _isPriceValid;
  }

  /// Valide les champs obligatoires de l'étape 0 (Trajet).
  /// Affiche un snackbar d'erreur si un champ manque et retourne false.
  /// Raison pour laquelle la date limite de dépôt saisie est invalide, ou null
  /// si elle est correcte (ou pas encore renseignée). Affichée en direct sous
  /// la ligne, utilisée pour bloquer le passage à l'étape suivante.
  String? _handoverDeadlineError() {
    final deadline = _handoverDeadlineNotifier.value;
    if (deadline == null) return null;
    final date = _departureDateNotifier.value;
    if (date == null) return null;
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
    final departureDay = DateTime(date.year, date.month, date.day);
    if (deadlineDay.isAfter(departureDay)) {
      return 'La date limite doit précéder le départ.';
    }
    return null;
  }

  /// Convertit le jour choisi en instant envoyé au backend.
  ///
  /// Le voyageur ne saisit qu'une date : on la borne à la fin de journée, sauf
  /// le jour du départ où la limite devient l'heure de départ — le backend
  /// refuse toute date limite postérieure au départ.
  DateTime? _resolveHandoverDeadline() {
    final deadline = _handoverDeadlineNotifier.value;
    if (deadline == null) return null;
    final date = _departureDateNotifier.value;
    final time = _departureTimeNotifier.value;
    final sameDayAsDeparture =
        date != null &&
        deadline.year == date.year &&
        deadline.month == date.month &&
        deadline.day == date.day;
    if (sameDayAsDeparture && time != null) {
      return DateTime(
        deadline.year,
        deadline.month,
        deadline.day,
        time.hour,
        time.minute,
      );
    }
    return DateTime(deadline.year, deadline.month, deadline.day, 23, 59);
  }

  void _syncCityToFormBloc() {
    if (!mounted) return;
    final formBloc = context.read<AnnouncementFormBloc>();
    if (_departureCityNotifier.value != null) {
      formBloc.add(
        DepartureCityChanged(
          _departureCityNotifier.value!,
          countryCode: _departureCountryCodeNotifier.value,
        ),
      );
    }
    if (_arrivalCityNotifier.value != null) {
      formBloc.add(
        ArrivalCityChanged(
          _arrivalCityNotifier.value!,
          countryCode: _arrivalCountryCodeNotifier.value,
        ),
      );
    }
  }

  void _syncDateToFormBloc() {
    if (!mounted) return;
    if (_departureDateNotifier.value != null) {
      context.read<AnnouncementFormBloc>().add(
        DepartureDateChanged(_departureDateNotifier.value!),
      );
    }
  }

  void _syncPriceToFormBloc() {
    if (!mounted) return;
    if (!_kgPriceEnabledNotifier.value) return; // évite d'écraser le clear
    if (_priceOptionNotifier.value == -1) return; // pas encore de sélection
    context.read<AnnouncementFormBloc>().add(PriceChanged(_pricePerKg));
  }

  void _syncKgToFormBloc() {
    if (!mounted) return;
    context.read<AnnouncementFormBloc>().add(
      AvailableKgChanged(_availableKgNotifier.value),
    );
  }

  void _syncDescriptionToFormBloc() {
    if (!mounted) return;
    final desc = _descriptionCtrl.text.trim();
    if (desc.isNotEmpty) {
      context.read<AnnouncementFormBloc>().add(DescriptionChanged(desc));
    }
  }

  void _syncTransportModeToFormBloc() {
    if (!mounted) return;
    final mode = _transportModeNotifier.value;
    if (mode != null) {
      context.read<AnnouncementFormBloc>().add(TransportModeChanged(mode));
    }
  }

  void _syncCashAcceptedToFormBloc() {
    if (!mounted) return;
    context.read<AnnouncementFormBloc>().add(
      CashAcceptedChanged(_cashEnabledNotifier.value),
    );
  }

  void _syncAcceptedTypesToFormBloc() {
    if (!mounted) return;
    final all = {
      ..._selectedContentNotifier.value,
      ..._customAcceptedNotifier.value,
    }.toList();
    context.read<AnnouncementFormBloc>().add(AcceptedTypesChanged(all));
  }

  void _syncDepartureTimeToParent() {
    widget.departureTimeNotifier?.value = _departureTimeNotifier.value;
  }

  void _syncRejectedTypesToFormBloc() {
    if (!mounted) return;
    context.read<AnnouncementFormBloc>().add(
      RejectedTypesChanged(_refusedTypesNotifier.value.toList()),
    );
  }

  void _onKgToggleChanged() {
    if (!mounted) return;
    if (!_kgPriceEnabledNotifier.value) {
      context.read<AnnouncementFormBloc>().add(
        const AnnouncementPricePerKgClearedRequested(),
      );
      _priceOptionNotifier.value = 0; // reset chips visuellement
    }
  }

  @override
  void dispose() {
    _departureCityNotifier.removeListener(_updateCanContinue);
    _arrivalCityNotifier.removeListener(_updateCanContinue);
    _departureDateNotifier.removeListener(_updateCanContinue);
    _departureTimeNotifier.removeListener(_updateCanContinue);
    _handoverDeadlineNotifier.removeListener(_updateCanContinue);
    _departureCityNotifier.removeListener(_syncCityToFormBloc);
    _arrivalCityNotifier.removeListener(_syncCityToFormBloc);
    _departureDateNotifier.removeListener(_syncDateToFormBloc);
    _priceOptionNotifier.removeListener(_syncPriceToFormBloc);
    _customPriceNotifier.removeListener(_syncPriceToFormBloc);
    _availableKgNotifier.removeListener(_syncKgToFormBloc);
    _descriptionCtrl.removeListener(_syncDescriptionToFormBloc);
    _transportModeNotifier.removeListener(_syncCanSubmit);
    _transportModeNotifier.removeListener(_syncTransportModeToFormBloc);
    _cashEnabledNotifier.removeListener(_syncCashAcceptedToFormBloc);
    _selectedContentNotifier.removeListener(_syncAcceptedTypesToFormBloc);
    _customAcceptedNotifier.removeListener(_syncAcceptedTypesToFormBloc);
    _refusedTypesNotifier.removeListener(_syncRejectedTypesToFormBloc);
    _departureTimeNotifier.removeListener(_syncDepartureTimeToParent);
    _kgPriceEnabledNotifier.removeListener(_onKgToggleChanged);
    _kgPriceEnabledNotifier.removeListener(_syncCanSubmit);
    _priceOptionNotifier.removeListener(_syncCanSubmit);
    _customPriceCtrl.removeListener(_syncCanSubmit);
    widget.currencyNotifier.removeListener(_syncCanSubmit);
    _kgPriceEnabledNotifier.dispose();
    _cashEnabledNotifier.dispose();
    _negotiableNotifier.dispose();
    _descriptionCtrl.dispose();
    _customAcceptedCtrl.dispose();
    _refusedCtrl.dispose();
    _customPriceCtrl.dispose();
    _customPriceNotifier.dispose();
    _departureCityNotifier.dispose();
    _arrivalCityNotifier.dispose();
    _departureCountryCodeNotifier.dispose();
    _arrivalCountryCodeNotifier.dispose();
    _departureDateNotifier.dispose();
    _departureTimeNotifier.dispose();
    _arrivalTimeNotifier.dispose();
    _handoverDeadlineNotifier.dispose();
    _availableKgNotifier.dispose();
    _priceOptionNotifier.dispose();
    _selectedContentNotifier.dispose();
    _customAcceptedNotifier.dispose();
    _catalogLabelsNotifier.dispose();
    _refusedTypesNotifier.dispose();
    _transportModeNotifier.dispose();
    _pickupAddressNotifier.dispose();
    _deliveryAddressNotifier.dispose();
    widget.currentStepNotifier?.removeListener(_markStep1TouchedOnEntry);
    for (final l in _userEditableListenables) {
      l.removeListener(_markDirty);
    }
    _step0ErrorsNotifier.dispose();
    _step1ErrorsNotifier.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Onboarding Stripe complet ? Lu depuis le `StripeAccountBloc` fourni par
  /// l'écran parent. Utilisé pour ne jamais soumettre une liste de méthodes
  /// de paiement vide (cash forcé quand Stripe n'est pas configuré).
  bool _isStripeConfigured() {
    final state = context.read<StripeAccountBloc>().state;
    return state is StripeAccountReady && state.accountStatus.isComplete;
  }

  void _submit({bool saveAsDraft = false}) {
    // Gate KYC — inchangé pour le reste du flux, nouveau uniquement ici :
    // publier/modifier un trajet nécessite une identité vérifiée. Si ce n'est
    // pas le cas, on ouvre l'onboarding KYC au lieu d'appeler l'API.
    final user = context.read<AuthBloc>().state.currentUser;
    if (!saveAsDraft && user != null && !user.isKycVerified) {
      unawaited(KycOnboardingBottomSheet.show(context));
      return;
    }

    final departureCity = _departureCityNotifier.value;
    final arrivalCity = _arrivalCityNotifier.value;
    final departureDate = _departureDateNotifier.value;
    final departureTimeVal = _departureTimeNotifier.value;
    final arrivalTimeVal = _arrivalTimeNotifier.value;

    if (departureCity == null) {
      _showError('Ville de départ obligatoire');
      return;
    }
    if (arrivalCity == null) {
      _showError('Ville d\'arrivée obligatoire');
      return;
    }
    if (departureDate == null) {
      _showError('Date de départ obligatoire');
      return;
    }
    // D1 : l'heure de départ est obligatoire (backstop du verrou d'annulation).
    if (departureTimeVal == null) {
      _showError('Heure de départ obligatoire');
      return;
    }

    _formKey.currentState!.save();

    if (_pickupAddress == null) {
      _showError('Lieu de remise du colis obligatoire');
      return;
    }
    if (_deliveryAddress == null) {
      _showError('Lieu de récupération obligatoire');
      return;
    }
    if (_transportModeNotifier.value == null) {
      _showError('Mode de transport obligatoire');
      return;
    }

    // departureTimeVal est garanti non-null par le guard plus haut (heure de
    // départ obligatoire — tranche A).
    final departureTime = _formatTime(departureTimeVal);
    final arrivalTime = arrivalTimeVal != null
        ? _formatTime(arrivalTimeVal)
        : null;

    final allAccepted = {
      ..._selectedContentNotifier.value,
      ..._customAcceptedNotifier.value,
    }.toList();
    final refused = _refusedTypesNotifier.value.toList();
    final description = _descriptionCtrl.text.trim().isEmpty
        ? null
        : _descriptionCtrl.text.trim();

    final transportMode = _transportModeNotifier.value!;

    if (_isLocked) {
      final lc = widget.lockContext!;
      final pickupAddress = {
        'label': _pickupAddress!.label,
        'lat': _pickupAddress!.lat,
        'lng': _pickupAddress!.lng,
      };
      final deliveryAddress = {
        'label': _deliveryAddress!.label,
        'lat': _deliveryAddress!.lat,
        'lng': _deliveryAddress!.lng,
      };

      if (lc.threadId != null) {
        final event = NegotiationCreateDedicatedTripRequested(
          threadId: lc.threadId!,
          departureDate: departureDate,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          pickupAddress: pickupAddress,
          deliveryAddress: deliveryAddress,
          description: description,
          acceptedContentTypes: allAccepted,
          refusedTypes: refused,
          paymentMethod: lc.paymentMethod,
        );
        context.read<NegotiationBloc>().add(event);
        return;
      }

      // No existing negotiation thread: the traveler reached this form
      // directly from the package request (no AWAITING_TRIP thread to link
      // to yet) — create the offer AND the dedicated trip atomically.
      final startEvent = NegotiationStartWithDedicatedTripRequested(
        packageRequestId: lc.packageRequestId,
        proposedPriceEur: lc.agreedPriceEur,
        travelerTravelDate: departureDate,
        travelerAvailableKg: lc.offerAvailableKg ?? lc.weightKg,
        body: lc.offerBody,
        dedicatedTrip: DedicatedTripPayload(
          departureDate: departureDate,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          pickupAddress: pickupAddress,
          deliveryAddress: deliveryAddress,
          description: description,
          acceptedContentTypes: allAccepted,
          refusedTypes: refused,
        ),
      );
      // Distingue ce flux de celui à thread existant au retour du bloc.
      _lastStartWithDedicatedTripEvent = startEvent;
      context.read<NegotiationBloc>().add(startEvent);
      return;
    }

    // Publiable sans Stripe (cash-only) : STRIPE n'est inclus que si
    // configuré, et CASH est forcé quand Stripe ne l'est pas — la liste ne
    // peut jamais être vide (au moins une méthode de paiement est requise).
    final stripeConfigured = _isStripeConfigured();
    final paymentMethods = [
      if (stripeConfigured) 'STRIPE',
      if (_cashEnabledNotifier.value || !stripeConfigured) 'CASH',
    ];

    final formBlocState = context.read<AnnouncementFormBloc>().state;
    final capacityUnitWire = formBlocState.capacityUnit.toWire();
    final pricingModeWire = formBlocState.pricingMode == PricingMode.mixed
        ? 'MIXED'
        : 'KG';
    final pricePerKgToSubmit = formBlocState.pricePerKg ?? 0.0;

    final handoverDeadline = _resolveHandoverDeadline();
    if (handoverDeadline == null) {
      _showError('Date limite de dépôt obligatoire');
      return;
    }
    final departureBound = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
      departureTimeVal.hour,
      departureTimeVal.minute,
    );
    if (handoverDeadline.isAfter(departureBound)) {
      _showError('La date limite de dépôt doit précéder le départ');
      return;
    }

    if (_isEdit) {
      context.read<AnnouncementBloc>().add(
        AnnouncementUpdateRequested(
          id: widget.announcement!.id,
          departureCity: departureCity,
          arrivalCity: arrivalCity,
          departureCountryCode: formBlocState.departureCountryCode,
          arrivalCountryCode: formBlocState.arrivalCountryCode,
          departureDate: departureDate,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          pickupAddress: _pickupAddress!,
          deliveryAddress: _deliveryAddress!,
          availableKg: _availableKgNotifier.value,
          pricePerKg: pricePerKgToSubmit,
          transportMode: transportMode,
          description: description,
          acceptedContentTypes: allAccepted,
          refusedTypes: refused,
          acceptedPaymentMethods: paymentMethods,
          capacityUnit: capacityUnitWire,
          pricingMode: pricingModeWire,
          handoverDeadline: handoverDeadline,
          negotiable: _negotiableNotifier.value,
        ),
      );
    } else {
      context.read<AnnouncementBloc>().add(
        AnnouncementCreateRequested(
          departureCity: departureCity,
          arrivalCity: arrivalCity,
          departureCountryCode: formBlocState.departureCountryCode,
          arrivalCountryCode: formBlocState.arrivalCountryCode,
          departureDate: departureDate,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          pickupAddress: _pickupAddress!,
          deliveryAddress: _deliveryAddress!,
          availableKg: _availableKgNotifier.value,
          pricePerKg: pricePerKgToSubmit,
          transportMode: transportMode,
          description: description,
          acceptedContentTypes: allAccepted,
          refusedTypes: refused,
          acceptedPaymentMethods: paymentMethods,
          capacityUnit: capacityUnitWire,
          pricingMode: pricingModeWire,
          handoverDeadline: handoverDeadline,
          negotiable: _negotiableNotifier.value,
          saveAsDraft: saveAsDraft,
          currency: _currency.code,
        ),
      );
    }
  }

  void _showError(String message) {
    DonySnackbar.show(context, message: message, type: DonySnackbarType.error);
  }

  Future<void> _selectDate() async {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    DateTime firstDate = today;
    DateTime lastDate = today.add(const Duration(days: 365));
    if (_isLocked) {
      final lc = widget.lockContext!;
      // Clamp to today as floor — backend rejects past dates regardless of tolerance.
      firstDate = lc.earliestDate.isBefore(today) ? today : lc.earliestDate;
      lastDate = lc.latestDate;
    }
    final initial =
        _departureDateNotifier.value ??
        (_isLocked
            ? widget.lockContext!.desiredDate
            : today.add(const Duration(days: 1)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: cs.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      _departureDateNotifier.value = picked;
    }
  }

  Future<void> _selectDepartureTime() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _departureTimeNotifier.value ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: cs.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      _departureTimeNotifier.value = picked;
    }
  }

  Future<void> _selectArrivalTime() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _arrivalTimeNotifier.value ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: cs.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      _arrivalTimeNotifier.value = picked;
    }
  }

  /// Sélection de la date limite de dépôt : un seul calendrier, pas d'heure.
  ///
  /// L'heure exacte se cale de toute façon dans le chat entre les deux parties,
  /// et la demander ici était la moitié de la friction de l'ancienne fenêtre.
  /// Le calendrier est borné à la date de départ quand elle est déjà saisie :
  /// une date limite postérieure au départ est impossible à choisir.
  Future<void> _selectHandoverDeadline() async {
    final cs = Theme.of(context).colorScheme;
    final departure = _departureDateNotifier.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = departure ?? today.add(const Duration(days: 365));
    final current = _handoverDeadlineNotifier.value;
    final initial = current != null && !current.isAfter(last) ? current : last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: last.isBefore(today) ? today : last,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: cs.primary)),
        child: child!,
      ),
    );
    if (picked != null) _handoverDeadlineNotifier.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    final formChild = _buildForm(context);
    if (_isLocked) {
      return BlocListener<NegotiationBloc, NegotiationState>(
        listener: (context, state) {
          if (state is NegotiationLoaded &&
              _lastStartWithDedicatedTripEvent != null) {
            // Brand-new offer + dedicated trip created atomically (no
            // pre-existing thread — cf. `_lastStartWithDedicatedTripEvent`).
            // `NegotiationBloc.start()` always leaves a freshly-created
            // thread OPEN (pending the sender's accept/reject/counter) — it
            // is never awaitingPayment straight away, since the sender
            // hasn't seen/accepted the offer yet. Mirrors the plain
            // `NegotiationStartRequested` success handling in
            // make_offer_bottom_sheet.dart, which pops on ANY NegotiationLoaded
            // without gating on thread status.
            // `pop(true)` : signale au caller (make_offer_bottom_sheet) qu'un
            // trajet a bien été créé, pour qu'il ferme la feuille d'offre
            // uniquement dans ce cas (pas sur un simple retour/annulation).
            context.pop(true);
            DonySnackbar.show(
              context,
              message: 'Offre envoyée avec le trajet associé.',
              type: DonySnackbarType.success,
            );
          } else if (state is NegotiationLoaded &&
              state.thread.status == NegotiationThreadStatus.awaitingPayment) {
            context.pop(true);
            DonySnackbar.show(
              context,
              message: 'Trajet lié. L\'expéditeur peut désormais payer.',
              type: DonySnackbarType.success,
            );
          } else if (state is NegotiationError) {
            // This screen OWNS payment-method-block feedback for the
            // dedicated-trip flow — LinkTripScreen, which shares this same
            // NegotiationBloc underneath, stands down while this screen is
            // on top (see its `_creatingDedicatedTripNotifier`). Reacting
            // here AND letting the generic ErrorPresenter also fire below
            // would show doubled, stacked feedback for a single 422.
            final block = PaymentCapabilityBlock.fromErrorCode(
              state.error.code,
            );
            if (block == PaymentCapabilityBlock.cardCapabilityRequired) {
              unawaited(showCardCapabilityRequiredSheet(context));
            } else {
              // Not a payment-method block: fall back to the generic error UX.
              ErrorPresenter.show(context, state.error);
            }
          }
        },
        child: formChild,
      );
    }

    return BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
      listenWhen: (prev, curr) => prev.pricingMode != curr.pricingMode,
      listener: (context, formState) {
        if (formState.pricingMode == PricingMode.mixed) {
          _kgPriceEnabledNotifier.value = false;
        } else {
          _kgPriceEnabledNotifier.value = true;
        }
      },
      child: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) async {
          if (state is AnnouncementCreated || state is AnnouncementUpdated) {
            final announcement = state is AnnouncementCreated
                ? state.announcement
                : (state as AnnouncementUpdated).announcement;
            final isEdit = state is AnnouncementUpdated;
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (routeContext) => DonySuccessScreen(
                    mascotteType: DonyMascotteType.succes,
                    title: isEdit ? 'Trajet modifié !' : 'Trajet publié !',
                    subtitle:
                        'Ton trajet ${announcement.departureCity} → ${announcement.arrivalCity} est en ligne.',
                    ctaLabel: 'Voir mon trajet',
                    ctaVariant: DonyButtonVariant.accent,
                    onCta: () {
                      // Le contexte de la route succès (routeContext) reste monté
                      // sous le Navigator racine après les deux pops ci-dessous —
                      // on capture donc le GoRouter AVANT de popper, pour éviter
                      // « Looking up a deactivated widget's ancestor is unsafe »
                      // (même classe de bug que le fix bid-payé, feb86b71).
                      final router = GoRouter.of(routeContext);
                      Navigator.of(
                        routeContext,
                      ).pop(); // ferme DonySuccessScreen
                      Navigator.of(context).pop(
                        true,
                      ); // ferme create_trip_screen — contrat bool intact pour les 3 appelants
                      router.push('/announcements/${announcement.id}/trip');
                    },
                    analyticsContext: 'trip_published',
                    secondaryLabel: isEdit ? null : 'Partager mon affiche',
                    // Le partage de texte seul ne convertit pas : sur Facebook,
                    // c'est le visuel qui arrête le regard, et le lien doit
                    // vivre dans la légende pour rester cliquable. On envoie
                    // donc vers l'affiche, qui fournit l'image, le lien et la
                    // légende en un seul écran.
                    // Même précaution de contexte que le CTA ci-dessus : le
                    // GoRouter est capturé AVANT les pops, routeContext étant
                    // démonté ensuite.
                    onSecondary: isEdit
                        ? null
                        : () {
                            final router = GoRouter.of(routeContext);
                            Navigator.of(routeContext).pop();
                            Navigator.of(context).pop(true);
                            router.push(
                              '/announcements/${announcement.id}/affiche',
                              extra: announcement,
                            );
                          },
                  ),
                ),
              ),
            );
          } else if (state is AnnouncementProLimitReached) {
            context.pop();
            if (context.mounted) {
              final confirmed = await DonyDialog.show(
                context,
                title: 'Limite mensuelle atteinte',
                message: state.message,
                confirmLabel: 'Passer en PRO',
                cancelLabel: 'Plus tard',
              );
              if (confirmed == true && context.mounted) {
                unawaited(context.push('/profile/upgrade-to-pro'));
              }
            }
          } else if (state is AnnouncementDraftLimitReached) {
            context.pop();
            if (context.mounted) {
              final confirmed = await DonyDialog.show(
                context,
                title: 'Limite de brouillons atteinte',
                message: state.message,
                confirmLabel: 'Passer en PRO',
                cancelLabel: 'Plus tard',
              );
              if (confirmed == true && context.mounted) {
                unawaited(context.push('/profile/upgrade-to-pro'));
              }
            }
          } else if (state is AnnouncementError) {
            unawaited(ErrorPresenter.show(context, state.error));
          }
        },
        builder: (context, state) =>
            BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
              listenWhen: (prev, curr) => prev.availableKg != curr.availableKg,
              listener: (context, formState) {
                final kg = formState.availableKg ?? 0.0;
                if (kg != _availableKgNotifier.value) {
                  _availableKgNotifier.value = kg;
                }
              },
              child: formChild,
            ),
      ),
    );
  }

  /// Applique un modèle de trajet enregistré : pré-remplit corridor, transport,
  /// capacité, poids, prix et contenu (les listeners synchronisent vers le BLoC).
  void _applyTemplate(TripTemplate t) {
    _departureCityNotifier.value = t.departureCity;
    _arrivalCityNotifier.value = t.arrivalCity;
    _transportModeNotifier.value =
        transportModeFromWire(t.transportMode) ?? TransportMode.plane;
    _availableKgNotifier.value = t.availableKg.toDouble();

    _kgPriceEnabledNotifier.value = true;
    final presetIdx = kPriceOptions.indexOf(t.pricePerKg);
    if (presetIdx != -1) {
      _priceOptionNotifier.value = presetIdx;
    } else {
      _priceOptionNotifier.value = kPriceOptions.length; // "Autre prix"
      _customPriceNotifier.value = t.pricePerKg;
      _customPriceCtrl.text = t.pricePerKg.toStringAsFixed(0);
    }

    _selectedContentNotifier.value = t.acceptedCategories
        .where(_catalogLabelsNotifier.value.contains)
        .toSet();
    _customAcceptedNotifier.value = t.acceptedCategories
        .where((c) => !_catalogLabelsNotifier.value.contains(c))
        .toSet();

    final unit = switch (t.capacityUnit) {
      'KG_FREE' => CapacityUnit.kgFree,
      'SUITCASE_32KG' => CapacityUnit.suitcase32kg,
      'KG_EXACT' => CapacityUnit.custom,
      _ => CapacityUnit.suitcase23kg,
    };
    context.read<AnnouncementFormBloc>().add(CapacityUnitChanged(unit));

    DonySnackbar.show(
      context,
      message: 'Modèle « ${t.label} » appliqué',
      type: DonySnackbarType.success,
    );
  }

  Widget _buildTemplatesSuggestionBar(
    BuildContext context,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return BlocBuilder<TripTemplateBloc, TripTemplateState>(
      builder: (context, state) {
        if (state.templates.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CaSectionLabel(label: 'Mes modèles', iconAsset: 'bookmark'),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Applique un modèle pour pré-remplir le trajet',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.sm),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.templates.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: DonySpacing.sm),
                itemBuilder: (context, i) {
                  final t = state.templates[i];
                  return ActionChip(
                    avatar: t.emoji != null
                        ? Text(t.emoji!)
                        : DonyIcon('bookmark', size: 16, color: cs.primary),
                    label: Text(
                      '${t.label} · ${CurrencyFormatter.formatOrPlain(t.pricePerKg, _currency, compact: true)}/kg',
                    ),
                    onPressed: () => _applyTemplate(t),
                  );
                },
              ),
            ),
            const SizedBox(height: DonySpacing.xl),
          ],
        );
      },
    );
  }

  // ── Step 0 — Trajet + Transport ─────────────────────────────────────────────
  List<Widget> _buildStep0(BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      if (_isLocked) ...[
        _LockedBanner(lockContext: widget.lockContext!),
        const SizedBox(height: DonySpacing.lg),
      ],
      if (!_isEdit && !_isLocked)
        ValueListenableBuilder<SupportedCurrency>(
          valueListenable: widget.currencyNotifier,
          builder: (context, _, _) =>
              _buildTemplatesSuggestionBar(context, tt, cs),
        ),
      ValueListenableBuilder<Set<_Step0Field>>(
        valueListenable: _step0ErrorsNotifier,
        builder: (context, missing, _) => TrajetStep(
          departureCityNotifier: _departureCityNotifier,
          arrivalCityNotifier: _arrivalCityNotifier,
          departureCountryCodeNotifier: _departureCountryCodeNotifier,
          arrivalCountryCodeNotifier: _arrivalCountryCodeNotifier,
          departureDateNotifier: _departureDateNotifier,
          departureTimeNotifier: _departureTimeNotifier,
          arrivalTimeNotifier: _arrivalTimeNotifier,
          onSelectDepartureTime: _selectDepartureTime,
          onSelectArrivalTime: _selectArrivalTime,
          onSelectDate: _selectDate,
          departureCityError: _msg(missing, _Step0Field.departureCity),
          arrivalCityError: _msg(missing, _Step0Field.arrivalCity),
          departureDateError: _msg(missing, _Step0Field.departureDate),
          departureTimeError: _msg(missing, _Step0Field.departureTime),
          // Corridor verrouillé en modification (Q1) ET en trajet dédié (lockContext).
          // Date verrouillée seulement en modification ; le dédié la garde éditable
          // dans la fenêtre de tolérance.
          lockCorridor: widget.lockCorridorAndDate || _isLocked,
          lockDate: widget.lockCorridorAndDate,
        ),
      ),
      const CaSectionLabel(label: 'DÉPÔT DES COLIS', iconAsset: 'package'),
      const SizedBox(height: DonySpacing.xs),
      CaSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<DateTime?>(
              valueListenable: _handoverDeadlineNotifier,
              builder: (context, dt, _) => ListTile(
                key: const Key('sheet-handover-deadline-row'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base,
                ),
                leading: DonyIcon(
                  'calendar',
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Date limite de dépôt'),
                subtitle: const Text(
                  'Jusqu\'à quand les expéditeurs peuvent te remettre leurs colis',
                ),
                trailing: Text(
                  dt != null ? DateFormat('d MMM', 'fr').format(dt) : 'Choisir',
                ),
                onTap: _selectHandoverDeadline,
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([
                _handoverDeadlineNotifier,
                _departureDateNotifier,
                _step0ErrorsNotifier,
              ]),
              builder: (context, _) {
                // Deux erreurs distinctes sur la même ligne : « date limite
                // incohérente » (postérieure au départ) et « date limite
                // absente » (rien de choisi). La seconde n'apparaît qu'après
                // une première interaction avec l'étape.
                final err =
                    _handoverDeadlineError() ??
                    (_step0ErrorsNotifier.value.contains(
                          _Step0Field.handoverDeadline,
                        )
                        ? _Step0Field.handoverDeadline.message
                        : null);
                return DonyFieldError(
                  message: err,
                  textKey: const Key('sheet-handover-error'),
                  withIcon: true,
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  // ── Step 1 — Lieux & Capacité ────────────────────────────────────────────────
  List<Widget> _buildStep1(BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      ValueListenableBuilder<Set<_Step1Field>>(
        valueListenable: _step1ErrorsNotifier,
        builder: (context, missing, _) => LieuxCapaciteStep(
          initialPickupAddress: _pickupAddressNotifier.value,
          initialDeliveryAddress: _deliveryAddressNotifier.value,
          onPickupSaved: (v) => _pickupAddressNotifier.value = v,
          onPickupChanged: (addr) {
            _pickupAddressNotifier.value = addr;
            _updateCanContinueStep1();
          },
          onDeliverySaved: (v) => _deliveryAddressNotifier.value = v,
          onDeliveryChanged: (addr) {
            _deliveryAddressNotifier.value = addr;
            _updateCanContinueStep1();
          },
          pickupAddressError: missing.contains(_Step1Field.pickupAddress)
              ? _Step1Field.pickupAddress.message
              : null,
          deliveryAddressError: missing.contains(_Step1Field.deliveryAddress)
              ? _Step1Field.deliveryAddress.message
              : null,
          // Trajet dédié : capacité fixée par la demande → affichage verrouillé.
          lockedCapacityKg: _isLocked ? widget.lockContext!.weightKg : null,
        ),
      ),
    ];
  }

  // ── Step 2 — Prix & Conditions ───────────────────────────────────────────────
  List<Widget> _buildStep2(BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      ValueListenableBuilder<SupportedCurrency>(
        valueListenable: widget.currencyNotifier,
        builder: (context, currency, _) => PrixConditionsStep(
          currency: currency,
          priceOptionNotifier: _priceOptionNotifier,
          customPriceNotifier: _customPriceNotifier,
          availableKgNotifier: _availableKgNotifier,
          cashEnabledNotifier: _cashEnabledNotifier,
          kgPriceEnabledNotifier: _kgPriceEnabledNotifier,
          negotiableNotifier: _negotiableNotifier,
          selectedContentNotifier: _selectedContentNotifier,
          customAcceptedNotifier: _customAcceptedNotifier,
          refusedTypesNotifier: _refusedTypesNotifier,
          catalogLabelsNotifier: _catalogLabelsNotifier,
          descriptionCtrl: _descriptionCtrl,
          customAcceptedCtrl: _customAcceptedCtrl,
          refusedCtrl: _refusedCtrl,
          customPriceCtrl: _customPriceCtrl,
          // Prix verrouillé en modification-pour-négo ET en trajet dédié : il
          // est fixé par la négociation.
          lockPrice: widget.lockCorridorAndDate || _isLocked,
          // Trajet dédié : affiche le prix total convenu et masque la section
          // « Modes de paiement » (déjà fixé par la négociation).
          lockedTotalPriceEur: _isLocked
              ? widget.lockContext!.agreedPriceEur
              : null,
          showPaymentMethods: !_isLocked,
        ),
      ),
    ];
  }

  Widget _buildForm(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Mode création ou édition — formulaire avec stepper.
    // Offstage garde les 3 steps dans l'arbre en permanence :
    // - les AddressPickerField (step 1) ne perdent pas leur état quand on
    //   navigue vers step 0 ou step 2
    // - form.validate() et form.save() couvrent tous les champs quelle que
    //   soit l'étape visible
    // - contrairement à IndexedStack, Offstage n'impose pas la hauteur du
    //   plus grand enfant : le sheet se dimensionne au contenu de l'étape active
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.currentStepNotifier,
        _pickupAddressNotifier,
        _deliveryAddressNotifier,
      ]),
      builder: (context, _) {
        final step = widget.currentStepNotifier!.value;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CaStepperHeader(currentStep: step, totalSteps: _totalSteps),
              const SizedBox(height: DonySpacing.lg),
              Offstage(
                offstage: step != 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildStep0(context, tt, cs),
                ),
              ),
              Offstage(
                offstage: step != 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildStep1(context, tt, cs),
                ),
              ),
              Offstage(
                offstage: step != 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildStep2(context, tt, cs),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const int _totalSteps = 3;
}

// ─── Champs obligatoires par étape ───────────────────────────────────────────

/// Champs obligatoires de l'étape 0, tels que `_submit()` les exige.
///
/// Toute entrée ajoutée ici bloque « Continuer » ET affiche son message sous
/// le champ concerné : impossible d'ajouter l'un sans l'autre.
enum _Step0Field {
  departureCity('Ville de départ obligatoire'),
  arrivalCity('Ville d\'arrivée obligatoire'),
  departureDate('Date de départ obligatoire'),
  departureTime('Heure de départ obligatoire'),
  transportMode('Mode de transport obligatoire'),
  handoverDeadline('Date limite de dépôt obligatoire');

  const _Step0Field(this.message);

  /// Message affiché sous le champ. Repris mot pour mot des gardes de
  /// `_submit()` pour que l'utilisateur lise la même chose aux deux endroits.
  final String message;
}

/// Champs obligatoires de l'étape 1.
enum _Step1Field {
  pickupAddress('Lieu de remise du colis obligatoire'),
  deliveryAddress('Lieu de récupération obligatoire');

  const _Step1Field(this.message);

  final String message;
}

// ─── Currency selection banner ────────────────────────────────────────────

/// Bannière interactive : annonce la devise choisie pour la publication et
/// ouvre le sélecteur partagé (`CurrencySelector`) au tap. Remplace l'ancienne
/// `CurrencyPublishBanner` statique — la devise n'était encore jamais
/// envoyée au serveur avant ce lot, elle se choisit désormais explicitement.
class _CurrencySelectionBanner extends StatelessWidget {
  const _CurrencySelectionBanner({required this.currencyNotifier});

  final ValueNotifier<SupportedCurrency> currencyNotifier;

  /// Moyens de paiement prévisualisés par devise. `stripeConfigured` reflète
  /// le compte Connect du créateur (seul voyageur concerné à cette étape) ;
  /// l'éligibilité Stripe par devise suit `SupportedCurrency.isStripeEligible`
  /// (verbatim contrainte serveur). Aperçu client uniquement : le serveur
  /// reste seul décideur au paiement réel.
  List<CurrencyPaymentOption> _options(bool stripeConfigured) => [
    for (final currency in SupportedCurrency.values)
      CurrencyPaymentOption(
        currency: currency,
        availablePaymentMethods: {
          BidPaymentMethod.cash,
          if (stripeConfigured && currency.isStripeEligible)
            BidPaymentMethod.stripe,
        },
      ),
  ];

  Future<void> _openSelector(BuildContext context) async {
    final stripeState = context.read<StripeAccountBloc>().state;
    final stripeConfigured =
        stripeState is StripeAccountReady &&
        stripeState.accountStatus.isComplete;
    final selected = await CurrencySelector.show(
      context,
      options: _options(stripeConfigured),
      initialCurrency: currencyNotifier.value,
    );
    if (selected != null) {
      currencyNotifier.value = selected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<SupportedCurrency>(
      valueListenable: currencyNotifier,
      builder: (context, currency, _) {
        final semanticsLabel =
            'Devise de publication : ${currency.displayName}, '
            '${currency.code}. Les utilisateurs dans une autre devise ne '
            'verront pas cette annonce. Bouton, modifier la devise.';
        return Semantics(
          container: true,
          button: true,
          label: semanticsLabel,
          child: ExcludeSemantics(
            child: InkWell(
              key: const Key('trip-currency-selector-row'),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              onTap: () => unawaited(_openSelector(context)),
              child: Container(
                padding: const EdgeInsets.all(DonySpacing.base),
                decoration: BoxDecoration(
                  color: cs.infoLight,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  border: Border.all(color: cs.info.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: cs.info),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Publié en ${currency.displayName} (${currency.code})',
                            style: tt.titleMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            'Les utilisateurs dans une autre devise ne verront pas cette annonce.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Text(
                      'Changer',
                      style: tt.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Locked banner & locked-mode helpers ─────────────────────────────────────

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.lockContext});
  final LockedTripContext lockContext;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('lock', size: 20, color: cs.primary),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trajet dédié à la demande',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Corridor, capacité et prix sont verrouillés. '
                  'La date doit rester dans la fenêtre de tolérance de l\'expéditeur.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
