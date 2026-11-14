import 'dart:async';

import 'package:dony/core/config/boat_carrier.dart';
import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:dony/core/utils/arrival_range.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_filled_fields_cubit.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_availability_cubit.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/trip_ai_draft_mapper.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_form_draft_launcher.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_entry_card.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_filled_banner.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/billing/presentation/pro_limit_dialog.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/kyc/data/kyc_recheck.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/trip_legs_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/boat_price_unit.dart';
import 'package:dony/features/matching/data/models/parcel_fit_wire.dart';
import 'package:dony/features/matching/data/models/trip_form_draft.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:dony/features/matching/presentation/trip_moment_corridor.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_preview_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/arrival_day_chips.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/conditions_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/currency_selection_banner.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/mode_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_currencies_confirm_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_legs_section.dart';
import 'package:dony/features/matching/presentation/widgets/trip_series/trip_series_card.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart'
    show NegotiationThreadStatus;
import 'package:dony/features/package_request/presentation/widgets/payment_capability_block_sheets.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_active.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/presentation/publish_blocked_screen.dart';
import 'package:dony/features/traveler_status/presentation/traveler_status_prompt.dart';
import 'package:dony/features/traveler_status/presentation/traveler_status_sheet.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:dony/features/video_modal/data/video_modal_moments.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Dates montrées par l'aperçu avant publication, lues dans le formulaire :
/// arrivée estimée du bateau et date limite de dépôt telle qu'elle partira.
typedef TripPreviewDates = ({
  DateTime? arrivalMin,
  DateTime? arrivalMax,
  DateTime? handoverDeadline,
});

class CreateTripArgs {
  final AnnouncementModel? announcement;
  final LockedTripContext? lockContext;
  final NegotiationBloc? negotiationBloc;
  final bool lockCorridorAndDate;

  /// Ouvert depuis la feuille des brouillons (« Terminer ce trajet ») : ce
  /// brouillon local est rechargé dès l'ouverture, à l'étape où il en était.
  final TripFormDraft? resumeDraft;

  /// Ouvert depuis « Mes modèles » de la feuille « Publier un trajet » : le
  /// modèle est appliqué dès l'ouverture, les dates restent à choisir.
  final TripTemplate? template;

  const CreateTripArgs({
    this.announcement,
    this.lockContext,
    this.negotiationBloc,
    this.lockCorridorAndDate = false,
    this.resumeDraft,
    this.template,
  });
}

class CreateTripScreen extends StatefulWidget {
  final CreateTripArgs? args;

  const CreateTripScreen({super.key, this.args});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  /// Pilote « Aperçu » / « Enregistrer » / « Confirmer » à l'étape
  /// Conditions : mode choisi et prix valide.
  late final ValueNotifier<bool> _canSubmitNotifier;

  /// Pilote « Continuer » à l'étape Prix (même règle que
  /// [_canSubmitNotifier], portée par l'étape où le prix se saisit).
  late final ValueNotifier<bool> _canContinuePriceNotifier;
  late final ValueNotifier<TripFormStep> _currentStepNotifier;
  late final ValueNotifier<bool> _canContinueNotifier;
  late final ValueNotifier<bool> _canContinueStep1Notifier;

  /// Mode du trajet. Porté par l'écran : « Continuer » de l'étape Mode en
  /// dépend. Le formulaire le pré-remplit (modification, trajet dédié,
  /// création sans choix de mode) et le lit à la soumission.
  final ValueNotifier<TransportMode?> _transportModeNotifier =
      ValueNotifier<TransportMode?>(null);

  /// Modes proposés à la publication, lus une fois à l'ouverture : un
  /// changement du drapeau en cours de saisie ne redessine pas les étapes.
  late final List<TransportMode> _tripModes;

  /// Étapes visibles, dans l'ordre (Mode seulement s'il y a un choix).
  late final List<TripFormStep> _steps;
  late final ValueNotifier<TimeOfDay?> _departureTimeNotifier;
  void Function({bool saveAsDraft})? _submit;

  /// Moyens de paiement tels qu'ils partiront au submit (FLUTTER-GJ) : l'aperçu
  /// les affiche au lieu de les recalculer.
  List<String> Function()? _paymentMethods;

  /// Dates de l'aperçu, lues dans le formulaire (cf. [TripPreviewDates]).
  TripPreviewDates Function()? _previewDates;

  /// Devise de l'annonce. En création, choisie par l'utilisateur (défaut :
  /// devise du portefeuille) ; en édition ou trajet dédié, figée sur la
  /// devise déjà portée par l'annonce/le verrou — elle ne se change plus une
  /// fois l'annonce publiée.
  late final ValueNotifier<SupportedCurrency> _currencyNotifier =
      ValueNotifier<SupportedCurrency>(_initialCurrency());

  /// Modification : la devise peut-elle encore changer ? Valeur servie par le
  /// serveur (`currencyEditable`, FLUTTER-KV) : `true` ouvre le sélecteur,
  /// `false` fige la devise avec une explication, `null` (champ absent, back
  /// antérieur) la fige sans rien ajouter. Repasse à `false` sur un 409
  /// `currency-locked` (demande arrivée entre-temps).
  late final ValueNotifier<bool?> _currencyEditableNotifier =
      ValueNotifier<bool?>(widget.args?.announcement?.currencyEditable);

  SupportedCurrency _initialCurrency() {
    final announcement = widget.args?.announcement;
    if (announcement != null) {
      return SupportedCurrency.fromCodeOrDefault(announcement.currency);
    }
    // Trajet dédié à une demande de colis : le prix convenu est dans la devise
    // de la demande, pas celle du portefeuille du voyageur. Sans cette ligne,
    // 50 000 XOF convenus s'affichaient « 50 000 € » à un voyageur parisien.
    final lock = widget.args?.lockContext;
    if (lock != null) {
      return SupportedCurrency.fromCodeOrDefault(lock.currency);
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

  /// Défilement du formulaire : le « Modifier » de la devise du récapitulatif
  /// remonte au sélecteur posé en tête (FLUTTER-NN).
  final ScrollController _formScrollController = ScrollController();

  /// Vrai pendant l'affichage du dialogue de confirmation, pour ne pas en
  /// empiler deux si l'utilisateur insiste sur le retour système.
  bool _confirmingExit = false;

  /// Brouillon local proposé en création seulement : un trajet modifié ou
  /// dédié à une demande part d'un contenu déjà connu.
  late final bool _draftsEnabled =
      widget.args?.announcement == null && widget.args?.lockContext == null;

  /// Porté par l'écran : la sortie et le bouton brouillon s'en servent depuis
  /// ce `State`, au-dessus des providers.
  late final FormDraftCubit? _draftCubit = _draftsEnabled
      ? getIt<FormDraftCubit>(param1: FormDraftKind.trip)
      : null;

  /// Fournis par le formulaire (cf. `_TripFormContent.onDraftHandlersReady`).
  TripFormDraft Function()? _draftSnapshot;
  void Function(TripFormDraft)? _restoreDraft;

  /// « Créer avec l'IA » : création libre seulement, ni modification, ni
  /// trajet dédié, ni reprise de brouillon, ni modèle appliqué (spec §2.1).
  late final AiFormDraftAvailabilityCubit? _aiAvailability =
      widget.args?.announcement == null &&
          widget.args?.lockContext == null &&
          widget.args?.resumeDraft == null &&
          widget.args?.template == null
      ? getIt<AiFormDraftAvailabilityCubit>()
      : null;

  /// Champs remplis par l'IA : marque « IA », bandeau, propriété `from_ai`.
  final AiFilledFieldsCubit _aiFilled = AiFilledFieldsCubit();

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    // Trajet dédié à une demande : tous les modes ouverts. Le bateau garde le
    // volume de la demande (lecture seule) et demande la fourchette d'arrivée ;
    // son voyageur doit être vérifié (carte grisée à l'étape Mode sinon).
    final modes = transportModes;
    _tripModes = modes.tripCreationModes;
    _steps = tripFormSteps(
      showModeStep: showModeStepFor(
        isEdit: args?.announcement != null,
        isLocked: args?.lockContext != null,
        // La demande « peu importe » (mode nul) laisse le choix du mode au
        // voyageur : l'étape Mode s'ouvre.
        lockedModeKnown: args?.lockContext?.transportMode != null,
        modes: modes,
      ),
    );
    _canSubmitNotifier = ValueNotifier<bool>(
      args?.announcement?.transportMode != null || args?.lockContext != null,
    );
    _canContinuePriceNotifier = ValueNotifier<bool>(_canSubmitNotifier.value);
    _currentStepNotifier = ValueNotifier<TripFormStep>(_steps.first);
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

    // La ligne « Carte bancaire » se lit sur le statut Stripe chargé au
    // démarrage du shell. S'il manque (session pas prête à ce moment-là),
    // a échoué ou date d'avant la fin de l'onboarding, la carte restait
    // verrouillée sur un compte pourtant complet (Sentry FLUTTER-CS/D2).
    // On redemande donc le statut à Stripe à chaque ouverture.
    final stripeBloc = getIt<StripeAccountBloc>();
    if (!stripeBloc.isClosed) {
      stripeBloc.add(const StripeAccountStatusRefreshed(showProgress: true));
    }

    final resumeDraft = args?.resumeDraft;
    if (_draftsEnabled && resumeDraft != null) {
      // Après la première frame : le formulaire doit avoir remis ses
      // fonctions de restauration (onDraftHandlersReady).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resumeLocalDraft(resumeDraft);
      });
    }
    final aiAvailability = _aiAvailability;
    if (aiAvailability != null) unawaited(aiAvailability.refresh());
  }

  @override
  void dispose() {
    _canSubmitNotifier.dispose();
    _canContinuePriceNotifier.dispose();
    _transportModeNotifier.dispose();
    _currentStepNotifier.dispose();
    _departureTimeNotifier.dispose();
    _canContinueNotifier.dispose();
    _canContinueStep1Notifier.dispose();
    _isDirtyNotifier.dispose();
    _currencyNotifier.dispose();
    _currencyEditableNotifier.dispose();
    _formScrollController.dispose();
    unawaited(_draftCubit?.close());
    unawaited(_aiFilled.close());
    super.dispose();
  }

  /// Formulaire quitté sans publier après avoir été commencé (saisie
  /// modifiée, donc `_isDirtyNotifier`) : moment d'action des modals, avec le
  /// corridor déjà saisi. Création seulement : un trajet modifié ou dédié à
  /// une demande n'est pas « abandonné ».
  void _notifyAbandoned() {
    if (!_draftsEnabled) return;
    TripFormDraft? draft;
    try {
      draft = _draftSnapshot?.call();
    } on Object {
      draft = null;
    }
    VideoModalMoments.notify(
      VideoModalMoment.action(
        VideoModalTrigger.formAbandoned,
        corridor: VideoModalMomentCorridor(
          fromCity: draft?.departureCity,
          fromCountryCode: draft?.departureCountryCode,
          toCity: draft?.arrivalCity,
          toCountryCode: draft?.arrivalCountryCode,
        ),
      ),
    );
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
    final draftCubit = _draftCubit;
    if (draftCubit == null) {
      final confirmed = await DonyDialog.confirmDiscard(context);
      _confirmingExit = false;
      if (!mounted || confirmed != true) return;
      _notifyAbandoned();
      _leave();
      return;
    }
    final choice = await DonyDialog.confirmExitWithDraft(context);
    _confirmingExit = false;
    if (!mounted || choice == null) return;
    switch (choice) {
      case DraftExitChoice.save:
        await _saveDraftAndLeave(FormDraftSource.exitDialog);
      case DraftExitChoice.discard:
        _notifyAbandoned();
        await draftCubit.discard(source: FormDraftSource.exitDialog);
        if (mounted) _leave();
    }
  }

  /// Garde la saisie en brouillon local, à l'étape où elle en est, puis
  /// quitte le formulaire. En cas d'échec, l'utilisateur reste sur sa saisie.
  Future<void> _saveDraftAndLeave(FormDraftSource source) async {
    final snapshot = _draftSnapshot;
    final draftCubit = _draftCubit;
    if (snapshot == null || draftCubit == null) return;
    final saved = await draftCubit.save(snapshot().toJson(), source: source);
    if (!mounted) return;
    if (!saved) {
      DonySnackbar.show(
        context,
        message: context.l10n.formDraftSaveFailedMessage,
        type: DonySnackbarType.error,
      );
      return;
    }
    DonySnackbar.show(
      context,
      message: context.l10n.formDraftSavedMessage,
      type: DonySnackbarType.success,
    );
    _notifyAbandoned();
    _leave();
  }

  /// Bouton « Brouillon » de la barre, disponible à chaque étape.
  void _onSaveDraftPressed() {
    if (!_isDirtyNotifier.value) {
      DonySnackbar.show(
        context,
        message: context.l10n.formDraftNothingToSaveMessage,
      );
      return;
    }
    unawaited(_saveDraftAndLeave(FormDraftSource.appBar));
  }

  /// Recharge le brouillon local choisi dans la feuille des brouillons, puis
  /// remet le voyageur à l'étape où il s'était arrêté, si les étapes
  /// précédentes sont toujours complètes : sinon à la première incomplète.
  /// Une étape absente de cet écran (Mode sans choix de mode) vaut Trajet.
  void _resumeLocalDraft(TripFormDraft restored) {
    _restoreDraft?.call(restored);
    final target = _steps.contains(restored.stepId)
        ? restored.stepId
        : TripFormStep.trajet;
    for (final step in _steps) {
      if (step == target || !_canLeave(step)) {
        _currentStepNotifier.value = step;
        return;
      }
    }
  }

  /// L'étape [step] est-elle complète (son bouton du bas actif) ?
  bool _canLeave(TripFormStep step) => switch (step) {
    TripFormStep.mode => _transportModeNotifier.value != null,
    TripFormStep.trajet => _canContinueNotifier.value,
    TripFormStep.capacite => _canContinueStep1Notifier.value,
    TripFormStep.prix => _canContinuePriceNotifier.value,
    TripFormStep.conditions => _canSubmitNotifier.value,
  };

  /// Étape voisine de [step] dans [_steps] (`delta` -1 ou +1), `null` au bord.
  TripFormStep? _stepBeside(TripFormStep step, int delta) {
    final i = _steps.indexOf(step) + delta;
    return i >= 0 && i < _steps.length ? _steps[i] : null;
  }

  /// Ouvre « Créer avec l'IA » puis applique le brouillon par le chemin de
  /// reprise de brouillon, posé sur la saisie courante, à la première étape.
  Future<void> _openAiDraft() async {
    final outcome = await getIt<AiFormDraftLauncher>().open(
      context,
      kind: AiFormKind.trip,
      defaultCurrency: _currencyNotifier.value.code,
      isCardReady: _isCardReady,
    );
    final snapshot = _draftSnapshot;
    final restore = _restoreDraft;
    if (!mounted || outcome == null || snapshot == null || restore == null) {
      return;
    }
    restore(TripAiDraftMapper.toFormDraft(outcome.draft, base: snapshot()));
    _currentStepNotifier.value = _steps.first;
    // « Reparler » complète : les marques de la passe précédente restent.
    _aiFilled.markFilled({..._aiFilled.state, ...outcome.filledFields});
    if (_formScrollController.hasClients) {
      unawaited(
        _formScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  /// Même règle que la ligne « Carte bancaire » du formulaire : onboarding
  /// Stripe Connect terminé.
  bool _isCardReady() {
    final state = getIt<StripeAccountBloc>().state;
    return state is StripeAccountReady && state.accountStatus.isComplete;
  }

  /// « Modifier » de la ligne Devise du récapitulatif (FLUTTER-NN) : ferme
  /// l'aperçu, revient à l'étape Prix dont l'encart de devise ouvre l'étape
  /// (FLUTTER-RA), remonte en tête du formulaire, puis ouvre
  /// directement son sélecteur. Création seulement : en modification ou en
  /// trajet dédié la devise est figée.
  Future<void> _changeCurrencyFromPreview(BuildContext formContext) async {
    Navigator.of(formContext, rootNavigator: true).pop();
    _currentStepNotifier.value = TripFormStep.prix;
    if (_formScrollController.hasClients) {
      await _formScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted || !formContext.mounted) return;
    await CurrencySelectionBanner.openSelector(formContext, _currencyNotifier);
  }

  /// La devise se choisit encore : création libre, ou modification d'un
  /// trajet que le serveur déclare modifiable (FLUTTER-KV). Jamais pour un
  /// trajet dédié, dont la devise est celle de la demande.
  bool get _canChangeCurrency {
    final args = widget.args;
    if (args?.lockContext != null) return false;
    if (args?.announcement == null) return true;
    return _currencyEditableNotifier.value == true;
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
      // Étapes supplémentaires d'un voyage (FLUTTER-4D), en création seulement.
      BlocProvider<TripLegsCubit>(create: (_) => getIt<TripLegsCubit>()),
      BlocProvider<AiFilledFieldsCubit>.value(value: _aiFilled),
      BlocProvider<MobileMoneyAccountBloc>(
        create: (_) =>
            getIt<MobileMoneyAccountBloc>()
              ..add(const MobileMoneyAccountsRequested()),
      ),
      // `.value` obligatoire : StripeAccountBloc est un lazySingleton GetIt
      // partagé par toute l'app. Avec `create:`, le provider fermerait le
      // singleton au démontage de l'écran et tout `add` ultérieur (reset au
      // logout, refresh après onboarding Connect) lèverait
      // « Cannot add new events after calling close ».
      BlocProvider<StripeAccountBloc>.value(value: getIt<StripeAccountBloc>()),
      if (args?.negotiationBloc != null)
        BlocProvider<NegotiationBloc>.value(value: args!.negotiationBloc!),
    ];

    final draftCubit = _draftCubit;
    if (draftCubit != null) {
      providers.add(BlocProvider<FormDraftCubit>.value(value: draftCubit));
    }

    return MultiBlocProvider(
      providers: providers,
      child: _withDraftListeners(
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
              actions: [
                if (_draftsEnabled)
                  IconButton(
                    key: const Key('trip-save-draft'),
                    tooltip: context.l10n.formDraftSaveTooltip,
                    onPressed: _onSaveDraftPressed,
                    icon: DonyIcon(
                      'notebook-pen',
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                const DonyFeedbackButton(),
              ],
              leading: DonyAppBarBackButton(
                leadingIconAsset: 'x',
                onBack: () => unawaited(_handleExitRequest()),
              ),
              title: Text(
                isLocked
                    ? context.l10n.tripPublishDedicatedTitle
                    : (isEdit
                          ? context.l10n.tripPublishEditTitle
                          : context.l10n.tripPublishTitle),
              ),
            ),
            resizeToAvoidBottomInset: true,
            // Bouton sticky dans `body` (pas `bottomNavigationBar`) : Flutter ne
            // remonte pas fiablement `bottomNavigationBar` au-dessus du clavier,
            // ce qui le cachait derrière sur les étapes Prix et Conditions
            // (champs prix, description). Même fix que phone_auth_screen.dart.
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _formScrollController,
                    padding: const EdgeInsets.all(DonySpacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_aiAvailability case final availability?)
                          _AiTripEntry(
                            availability: availability,
                            filled: _aiFilled,
                            currentStepNotifier: _currentStepNotifier,
                            firstStep: _steps.first,
                            onOpen: () => unawaited(_openAiDraft()),
                          ),
                        const SizedBox(height: DonySpacing.base),
                        // L'encart de devise vit en tête de l'étape Prix,
                        // juste avant les prix (FLUTTER-RA) : il n'a rien à
                        // faire à l'étape des villes et dates.
                        _TripFormContent(
                          // Réservé aux tests : cf. `handoverDeadlineForTest`
                          // sur `_TripFormContentState`, atteint via ce Key
                          // faute de pouvoir nommer `_TripFormContent` (privé)
                          // depuis un autre fichier.
                          key: const Key('trip-form-content'),
                          announcement: args?.announcement,
                          initialTemplate: args?.template,
                          lockContext: args?.lockContext,
                          lockCorridorAndDate:
                              args?.lockCorridorAndDate ?? false,
                          steps: _steps,
                          tripModes: _tripModes,
                          transportModeNotifier: _transportModeNotifier,
                          canSubmitNotifier: _canSubmitNotifier,
                          canContinuePriceNotifier: _canContinuePriceNotifier,
                          onPreviewRequested: _openPreview,
                          canContinueNotifier: _canContinueNotifier,
                          canContinueStep1Notifier: _canContinueStep1Notifier,
                          currentStepNotifier: _currentStepNotifier,
                          departureTimeNotifier: _departureTimeNotifier,
                          currencyNotifier: _currencyNotifier,
                          currencyEditableNotifier: _currencyEditableNotifier,
                          onSubmitReady: (fn) => _submit = fn,
                          onPaymentMethodsReady: (fn) => _paymentMethods = fn,
                          onPreviewDatesReady: (fn) => _previewDates = fn,
                          onDraftHandlersReady: (snapshot, restore) {
                            _draftSnapshot = snapshot;
                            _restoreDraft = restore;
                          },
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
                        _canContinuePriceNotifier,
                        _currentStepNotifier,
                        _canContinueNotifier,
                        _canContinueStep1Notifier,
                        _transportModeNotifier,
                      ]),
                      builder: (ctx, _) {
                        final step = _currentStepNotifier.value;
                        final canSubmit = _canSubmitNotifier.value;
                        final previous = _stepBeside(step, -1);
                        // Retour 2/5 sans icône, bouton principal 3/5 : à
                        // 360 dp, deux moitiés égales avec leurs icônes
                        // rétrécissaient « Continuer » et « Retour » dans le
                        // FittedBox de DonyButton.
                        final backButton = previous == null
                            ? null
                            : DonyButton(
                                label: ctx.l10n.commonBack,
                                variant: DonyButtonVariant.secondary,
                                onPressed: () =>
                                    _currentStepNotifier.value = previous,
                              );
                        final back = backButton == null
                            ? null
                            : Expanded(flex: 2, child: backButton);

                        // ── Avant Conditions : Continuer (+ Retour) ──
                        final next = _stepBeside(step, 1);
                        if (next != null) {
                          return Row(
                            children: [
                              if (back != null) ...[
                                back,
                                const SizedBox(width: DonySpacing.sm),
                              ],
                              Expanded(
                                flex: 3,
                                child: DonyButton(
                                  key: const Key('trip-form-continue'),
                                  label: ctx.l10n.commonContinue,
                                  iconRight: DonyIcons.arrowRight,
                                  onPressed: _canLeave(step)
                                      ? () => _currentStepNotifier.value = next
                                      : null,
                                ),
                              ),
                            ],
                          );
                        }

                        // ── Conditions — Trajet dédié : Confirmer ──
                        if (isLocked) {
                          return BlocBuilder<NegotiationBloc, NegotiationState>(
                            builder: (ctx, state) {
                              final isLoading =
                                  state is NegotiationLoading ||
                                  state is NegotiationActionInProgress;
                              // « Confirmer le trajet » est trop long pour
                              // tenir à côté de « Retour » : boutons empilés,
                              // le principal en haut.
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DonyButton(
                                    key: const Key(
                                      'create-dedicated-trip-submit',
                                    ),
                                    label: ctx.l10n.tripPublishSubmitDedicated,
                                    isLoading: isLoading,
                                    onPressed: (canSubmit && !isLoading)
                                        ? () => _submit?.call()
                                        : null,
                                  ),
                                  if (backButton != null) ...[
                                    const SizedBox(height: DonySpacing.sm),
                                    backButton,
                                  ],
                                ],
                              );
                            },
                          );
                        }

                        // ── Conditions — Mode édition : Enregistrer ──
                        if (isEdit) {
                          return BlocBuilder<
                            AnnouncementBloc,
                            AnnouncementState
                          >(
                            builder: (ctx, state) {
                              final isLoading = state is AnnouncementLoading;
                              return Row(
                                children: [
                                  ?back,
                                  const SizedBox(width: DonySpacing.sm),
                                  Expanded(
                                    flex: 3,
                                    child: DonyButton(
                                      key: const Key(
                                        'create-announcement-submit',
                                      ),
                                      label: ctx.l10n.commonSave,
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

                        // ── Conditions — Mode création : Aperçu ──
                        // Publiable sans Stripe configuré (cash-only) — Stripe n'est
                        // plus une condition bloquante ici, seule la section paiement
                        // (PrixStep) reflète le verrouillage de la carte.
                        return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                          builder: (ctx, annState) {
                            final isLoading = annState is AnnouncementLoading;
                            return Row(
                              children: [
                                ?back,
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  flex: 3,
                                  child: DonyButton(
                                    key: const Key(
                                      'create-announcement-preview',
                                    ),
                                    label: ctx.l10n.tripPublishPreviewButton,
                                    iconRight: DonyIcons.arrowRight,
                                    isLoading: isLoading,
                                    onPressed: (canSubmit && !isLoading)
                                        ? () => _openPreview(ctx)
                                        : null,
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  /// Aperçu du trajet avant publication : bouton « Aperçu » de la barre et
  /// « Passer » de l'étape Conditions. [ctx] doit voir les blocs de l'écran.
  void _openPreview(BuildContext ctx) {
    final isLoading = ctx.read<AnnouncementBloc>().state is AnnouncementLoading;
    final dates = _previewDates?.call();
    AnnouncementPreviewSheet.show(
      ctx,
      formState: ctx.read<AnnouncementFormBloc>().state,
      onConfirm: () {
        // Intentional: closes the preview sheet, not the CreateTripScreen.
        Navigator.of(ctx, rootNavigator: true).pop();
        _submit?.call();
      },
      onSaveDraft: () {
        // Même fermeture du sheet que onConfirm.
        Navigator.of(ctx, rootNavigator: true).pop();
        _submit?.call(saveAsDraft: true);
      },
      isSubmitting: isLoading,
      departureTime: _departureTimeNotifier.value,
      currency: _currencyNotifier.value,
      paymentMethods: _paymentMethods?.call(),
      // Bateau : fourchette d'arrivée ; tous modes : date limite de dépôt,
      // telle qu'elle partira au serveur. Rien tant qu'elles ne sont pas
      // saisies.
      arrivalMin: dates?.arrivalMin,
      arrivalMax: dates?.arrivalMax,
      handoverDeadline: dates?.handoverDeadline,
      // « Modifier » : en création, ou en modification d'un trajet encore
      // sans demande (FLUTTER-KV).
      onChangeCurrency: _canChangeCurrency
          ? () => unawaited(_changeCurrencyFromPreview(ctx))
          : null,
    );
  }

  /// En création seulement : le brouillon local est effacé une fois le
  /// trajet publié (ou enregistré en brouillon serveur).
  Widget _withDraftListeners({required Widget child}) {
    final draftCubit = _draftCubit;
    if (draftCubit == null) return child;
    return BlocListener<AnnouncementBloc, AnnouncementState>(
      listenWhen: (_, next) => next is AnnouncementCreated,
      listener: (_, _) => unawaited(draftCubit.clear()),
      child: child,
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

  /// Étapes visibles, dans l'ordre (cf. `_CreateTripScreenState._steps`).
  final List<TripFormStep> steps;

  /// Modes proposés à la publication (cartes de l'étape Mode, puces de la
  /// ligne du mode).
  final List<TransportMode> tripModes;

  /// Mode du trajet, porté par l'écran (cf. `_CreateTripScreenState`).
  final ValueNotifier<TransportMode?> transportModeNotifier;
  final ValueNotifier<bool>? canSubmitNotifier;
  final ValueNotifier<bool>? canContinuePriceNotifier;
  final ValueNotifier<bool>? canContinueNotifier;
  final ValueNotifier<bool>? canContinueStep1Notifier;
  final ValueNotifier<TripFormStep>? currentStepNotifier;

  /// Ouvre l'aperçu (« Passer » de l'étape Conditions, comme « Aperçu »).
  final void Function(BuildContext context)? onPreviewRequested;

  /// Passe à true dès la première modification utilisateur. Le parent s'en
  /// sert pour décider si quitter l'écran doit être confirmé.
  final ValueNotifier<bool>? dirtyNotifier;
  final ValueNotifier<TimeOfDay?>? departureTimeNotifier;

  /// Devise de l'annonce, portée par le parent (cf. `_CreateTripScreenState`).
  /// Choisie par l'utilisateur en création, figée en édition/trajet dédié.
  final ValueNotifier<SupportedCurrency> currencyNotifier;

  /// Devise encore modifiable en édition (cf. `_CreateTripScreenState`).
  /// `null` en création comme pour un back antérieur.
  final ValueNotifier<bool?>? currencyEditableNotifier;
  final void Function(void Function({bool saveAsDraft}))? onSubmitReady;
  final void Function(List<String> Function())? onPaymentMethodsReady;
  final void Function(TripPreviewDates Function())? onPreviewDatesReady;

  /// Remet au parent de quoi lire la saisie (brouillon local) et la
  /// recharger (reprise du brouillon).
  final void Function(
    TripFormDraft Function() snapshot,
    void Function(TripFormDraft) restore,
  )?
  onDraftHandlersReady;

  /// Modèle à appliquer dès l'ouverture (cf. `CreateTripArgs.template`).
  final TripTemplate? initialTemplate;

  const _TripFormContent({
    super.key,
    this.announcement,
    this.initialTemplate,
    this.lockContext,
    this.lockCorridorAndDate = false,
    required this.steps,
    required this.tripModes,
    required this.transportModeNotifier,
    this.canSubmitNotifier,
    this.canContinuePriceNotifier,
    this.onPreviewRequested,
    this.canContinueNotifier,
    this.canContinueStep1Notifier,
    this.currentStepNotifier,
    this.dirtyNotifier,
    this.departureTimeNotifier,
    required this.currencyNotifier,
    this.currencyEditableNotifier,
    this.onSubmitReady,
    this.onPaymentMethodsReady,
    this.onPreviewDatesReady,
    this.onDraftHandlersReady,
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

  /// Jours entre le départ et l'arrivée (vol de nuit, escale : FLUTTER-4E).
  final _arrivalDayOffsetNotifier = ValueNotifier<int>(0);

  /// Bateau : arrivée estimée au plus tôt et au plus tard, jours sans heure
  /// (`arrivalDate`, `arrivalDateMax`). Remplacent l'heure et le jour
  /// d'arrivée, jamais envoyées hors bateau.
  final _boatArrivalMinNotifier = ValueNotifier<DateTime?>(null);
  final _boatArrivalMaxNotifier = ValueNotifier<DateTime?>(null);

  /// Bateau au m³ : prix net par m³ saisi (étape Prix). Recopié dans le bloc
  /// (aperçu) ; lu à l'envoi.
  final _pricePerM3Ctrl = TextEditingController();

  /// Bateau : unité de vente (m³ ou kilo). Même schéma que
  /// [_availableKgNotifier] : `CapacityControl` l'écrit dans le bloc, un
  /// `BlocListener` la recopie ici ; le formulaire la pose lui-même
  /// (modification, brouillon), sans attendre le bloc, pour décider tout de
  /// suite de la règle du prix. `null` tant que le bateau n'est pas choisi.
  final _boatPriceUnitNotifier = ValueNotifier<BoatPriceUnit?>(null);

  /// Date limite de dépôt : jour et heure choisis par le voyageur
  /// (FLUTTER-PK). Une valeur à minuit est un jour sans heure (modèle
  /// appliqué, ancien brouillon, heure annulée) : son heure se déduit à
  /// l'envoi (cf. [_resolveHandoverDeadline]).
  final _handoverDeadlineNotifier = ValueNotifier<DateTime?>(null);

  /// Réservé aux tests : lecture seule de la date limite de dépôt, pour
  /// vérifier son recalcul après application d'un modèle sans piloter le
  /// calendrier natif (cf. `handoverDeadlineOf` dans les tests).
  @visibleForTesting
  ValueListenable<DateTime?> get handoverDeadlineForTest =>
      _handoverDeadlineNotifier;
  final _pickupAddressNotifier = ValueNotifier<AddressData?>(null);
  final _deliveryAddressNotifier = ValueNotifier<AddressData?>(null);
  AddressData? get _pickupAddress => _pickupAddressNotifier.value;
  AddressData? get _deliveryAddress => _deliveryAddressNotifier.value;
  // Même défaut que le bloc (une valise de 23 kg) : le compteur affiche le
  // bloc, la soumission lit ce notifier (YADONY-FLUTTER-PROD-18).
  final _availableKgNotifier = ValueNotifier<double>(defaultAvailableKg);
  final _priceOptionNotifier = ValueNotifier<int>(-1); // -1 = aucune sélection
  ValueNotifier<TransportMode?> get _transportModeNotifier =>
      widget.transportModeNotifier;

  /// Le voyageur choisit son mode à l'étape Mode : un mode absent (modèle,
  /// brouillon) reste à choisir au lieu de valoir l'avion.
  bool get _hasModeStep => widget.steps.contains(TripFormStep.mode);

  /// La ligne « Mode de transport » de l'étape Trajet est montrée.
  late final bool _showModeRow;

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

  // Rien de coché d'office : trois catégories présélectionnées étaient
  // « pas utiles » (FLUTTER-1Y). Une liste vide = tous les contenus acceptés.
  final _selectedContentNotifier = ValueNotifier<Set<String>>({});
  final _customAcceptedNotifier = ValueNotifier<Set<String>>({});
  // Catalogue de types de contenu — seedé synchrone avec le catalogue
  // embarqué (fallbackCatalog), puis remplacé par le catalogue live du
  // repository dès qu'il répond (repli automatique hors ligne intégré).
  final _catalogLabelsNotifier = ValueNotifier<List<String>>(
    fallbackCatalog.map((c) => c.label).toList(),
  );
  final _refusedTypesNotifier = ValueNotifier<Set<String>>({});
  final _cashEnabledNotifier = ValueNotifier<bool>(false);

  /// Le voyageur garde la carte sur ce trajet (FLUTTER-FT) : cochée par
  /// défaut, elle n'est envoyée que si Stripe Connect est prêt et la devise
  /// éligible.
  final _cardEnabledNotifier = ValueNotifier<bool>(true);

  /// Escales du vol (FLUTTER-GE), facultatives, envoyées pour l'avion seul.
  final _stopsNotifier = ValueNotifier<TripStops?>(null);

  /// Le voyageur accepte le paiement par mobile money (Orange Money, Wave,
  /// MTN via pawaPay). Uniquement pertinent pour un trajet en zone CFA
  /// (XOF/XAF) — remis à `false` par [_onCurrencyChanged] si la devise
  /// quitte cette zone après activation.
  final _mobileMoneyEnabledNotifier = ValueNotifier<bool>(false);

  /// Le voyageur ouvre son trajet aux propositions de prix des expéditeurs.
  final _negotiableNotifier = ValueNotifier<bool>(false);
  late final ValueNotifier<bool> _kgPriceEnabledNotifier;

  /// Prix au kilo d'un brouillon restauré qui change de mode de tarification
  /// (brouillon IA « grille + 10 €/kg », brouillon local) : le changement de
  /// mode coupe l'interrupteur, ce qui effaçait le prix. Le listener du mode
  /// réapplique cette valeur une fois, au lieu de couper.
  bool? _pendingKgPriceEnabled;
  final _descriptionCtrl = TextEditingController();
  final _customAcceptedCtrl = TextEditingController();
  final _refusedCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _customPriceNotifier = ValueNotifier<double>(6.0);

  bool get _isEdit => widget.announcement != null;
  bool get _isLocked => widget.lockContext != null;

  /// Trajet en bateau (mode choisi, du trajet modifié ou de la demande à
  /// laquelle il est dédié).
  bool get _isBoat => _transportModeNotifier.value == TransportMode.boat;

  /// Trajet dédié bateau dont le voyageur n'est pas vérifié (ni badge GP Pro ni
  /// compte pro) : le serveur le refuserait en 403 `boat-carrier-not-verified`,
  /// l'étape Trajet l'explique et reste bloquée. Une demande « peu importe »
  /// laisse choisir un autre mode (la carte Bateau est alors grisée).
  bool get _lockedBoatBlocked =>
      _isLocked && _isBoat && !_hasModeStep && !_canPublishBoat;

  /// Trajet bateau vendu au m³ (unité de l'étape Capacité) : aucun kilo
  /// n'est envoyé. Un trajet dédié bateau est toujours au m³ (le volume est
  /// celui de la demande).
  bool get _isBoatPerM3 =>
      _isBoat &&
      (_isLocked || _boatPriceUnitNotifier.value == BoatPriceUnit.m3);

  /// Le voyageur peut publier en bateau (badge GP Pro ou compte pro, C15).
  bool get _canPublishBoat {
    final user = context.read<AuthBloc>().state.currentUser;
    return user != null && canPublishBoat(user);
  }

  /// Modification d'un trajet dont la devise peut encore changer (FLUTTER-KV).
  bool get _isEditCurrencyEditable =>
      _isEdit && widget.currencyEditableNotifier?.value == true;

  /// Devise de l'annonce — suit le sélecteur du parent (`_CreateTripScreenState`),
  /// pas la devise active du profil : une annonce se publie désormais dans la
  /// devise choisie à la création, potentiellement distincte du portefeuille.
  SupportedCurrency get _currency => widget.currencyNotifier.value;

  /// Chips de prix de la devise de l'annonce (1 000 à 3 000 F CFA/kg en zone
  /// CFA, 5 à 8 €/kg en euro). Un même index désigne donc un autre montant
  /// dès que le sélecteur de devise change.
  List<double> get _presets => KgPriceReference.forCurrency(_currency).presets;
  bool get _isCustomPrice => _priceOptionNotifier.value == _presets.length;
  double get _pricePerKg => _isCustomPrice
      ? _customPriceNotifier.value
      : _presets[_priceOptionNotifier.value.clamp(0, _presets.length - 1)];

  // Vrai si le prix est correctement renseigné :
  // — mode verrouillé → prix fixé par la demande, toujours valide
  // — kg toggle OFF (mode grille) → tarification via la grille, toujours valide
  // — aucun choix effectué (idx == -1) → invalide
  // — chip preset sélectionnée → valide
  // — "Autre prix" sélectionné → le champ doit contenir un nombre compris
  //   entre le plancher et le plafond de la devise DE L'ANNONCE (pas celle du
  //   profil) : changer de devise dans le sélecteur fait donc suivre ces
  //   bornes, sans quoi un montant valide en XOF resterait bloqué au plafond
  //   (bien plus bas) de l'euro, ou l'inverse laisserait passer un montant
  //   que le serveur refuserait. Le plancher (1 €/kg converti) arrête les
  //   8 XOF/kg saisis en croyant taper des euros (FLUTTER-GK).
  bool get _isPriceValid {
    if (_isLocked) return true;
    // Bateau au m³ : la règle du bloc (0,01 à 99 999 999,99), appliquée à la
    // saisie courante. Le bloc ne reçoit la saisie qu'un instant plus tard
    // (événement asynchrone) alors que la reprise d'un brouillon lit ce
    // résultat tout de suite : on évalue donc l'état avec le prix du champ.
    if (_isBoatPerM3) {
      return context
          .read<AnnouncementFormBloc>()
          .state
          .copyWith(
            pricePerM3Getter: () => parsePriceInput(_pricePerM3Ctrl.text),
          )
          .isPricePerM3Valid;
    }
    if (!_kgPriceEnabledNotifier.value) return true;
    final idx = _priceOptionNotifier.value;
    if (idx == -1) return false;
    if (!_isCustomPrice) return true;
    final parsed = double.tryParse(_customPriceCtrl.text.replaceAll(',', '.'));
    return parsed != null &&
        parsed > 0 &&
        unitPriceOutOfBounds(parsed, _currency) == null;
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
      _departureDateNotifier.value = ctx.preferredDate ?? ctx.desiredDate;
      _availableKgNotifier.value = ctx.weightKg;
      // Demande « peu importe » : l'avion d'office, le voyageur peut en
      // changer à l'étape Mode qui s'ouvre alors d'elle-même.
      _transportModeNotifier.value = ctx.transportMode ?? TransportMode.plane;
    }
    if (_isEdit) {
      final a = widget.announcement!;
      _departureCityNotifier.value = a.departureCity;
      _arrivalCityNotifier.value = a.arrivalCity;
      _departureCountryCodeNotifier.value = a.departureCountryCode;
      _arrivalCountryCodeNotifier.value = a.arrivalCountryCode;
      _departureDateNotifier.value = a.departureDate;
      // En heure locale : le jour comparé à celui du départ en dépend.
      _handoverDeadlineNotifier.value = _initialEditHandoverDeadline(a);
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
      final arrivalDate = a.arrivalDate;
      if (arrivalDate != null) {
        // Borné au mode du trajet (J+14 en route) : un trajet route à J+10
        // ne doit pas être ramené à J+2 à l'ouverture.
        _arrivalDayOffsetNotifier.value = DateUtils.dateOnly(arrivalDate)
            .difference(DateUtils.dateOnly(a.departureDate))
            .inDays
            .clamp(0, transportModeOrPlane(a.transportMode).maxArrivalDays);
      }
      _pickupAddressNotifier.value = a.pickupAddress;
      _deliveryAddressNotifier.value = a.deliveryAddress;
      // Mode courant gardé tel quel, même non proposable (BOAT, TRAIN
      // publiés ailleurs) : il repart à l'enregistrement. Absent des
      // anciennes données : avion.
      _transportModeNotifier.value = transportModeOrPlane(a.transportMode);
      _stopsNotifier.value = a.stops;
      // Bateau : unité de vente, fourchette d'arrivée et prix au m³ relus
      // tels quels.
      if (a.transportMode == TransportMode.boat) {
        _boatPriceUnitNotifier.value = a.isPricedPerM3
            ? BoatPriceUnit.m3
            : BoatPriceUnit.kg;
        final min = a.arrivalDate;
        final max = a.arrivalDateMax;
        _boatArrivalMinNotifier.value = min == null
            ? null
            : DateUtils.dateOnly(min);
        _boatArrivalMaxNotifier.value = max == null
            ? null
            : DateUtils.dateOnly(max);
        final pricePerM3 = a.pricePerM3;
        if (pricePerM3 != null) {
          _pricePerM3Ctrl.text = _priceInputText(pricePerM3);
        }
      }

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
      _cardEnabledNotifier.value = a.acceptedPaymentMethods.contains(
        BidPaymentMethod.stripe,
      );
      _mobileMoneyEnabledNotifier.value = a.acceptedPaymentMethods.contains(
        BidPaymentMethod.mobileMoney,
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
        final presetIdx = _presets.indexOf(price);
        if (presetIdx != -1) {
          _priceOptionNotifier.value = presetIdx;
        } else {
          // Prix custom — sélectionner "Autre" et pré-remplir le champ
          _priceOptionNotifier.value = _presets.length;
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
        // L'unité réécrit le kg à sa contenance (une valise) ; le kg du
        // trajet passe ensuite, sinon un trajet de deux valises, ou déjà
        // en partie réservé, s'enregistrait à une seule valise pleine.
        formBloc
          ..add(EditingTripStarted(fromVolumeSale: a.isPricedPerM3))
          ..add(AvailableKgChanged(a.availableKg));
        // Taille (route) et poids max par colis (route, bateau) : relus tels
        // quels, renvoyés seulement si le voyageur les change (cf. _submit).
        // Sans cette relecture, un poids max d'un trajet bateau partait
        // effacé au premier enregistrement.
        final tripMode = transportModeOrPlane(a.transportMode);
        if (tripMode.hasItemSize) {
          formBloc.add(MaxItemSizeChanged(a.maxItemSize));
        }
        if (tripMode.hasMaxParcelWeight) {
          formBloc.add(MaxParcelWeightChanged(a.maxParcelWeightKg));
        }
        // Bateau : volume et prix au m³ du trajet (l'unité est partie avec
        // le mode, cf. _syncTransportModeToFormBloc).
        if (tripMode == TransportMode.boat) {
          formBloc
            ..add(VolumeCapacityChanged(a.volumeCapacityM3))
            ..add(PricePerM3Changed(a.pricePerM3));
        }

        // Pas de grille en bateau.
        final mode = a.pricingMode == 'MIXED' && tripMode != TransportMode.boat
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
    if (!_isEdit) _seedAvailableKgToFormBloc();
    widget.onSubmitReady?.call(_submit);
    widget.onPaymentMethodsReady?.call(_paymentMethods);
    widget.onPreviewDatesReady?.call(_previewDates);
    widget.onDraftHandlersReady?.call(_draftSnapshot, _restoreDraft);
    final initialTemplate = widget.initialTemplate;
    if (initialTemplate != null && widget.announcement == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyTemplate(initialTemplate);
      });
    }
    _kgPriceEnabledNotifier = ValueNotifier<bool>(true); // KG = ON par défaut
    _kgPriceEnabledNotifier.addListener(_onKgToggleChanged);
    _kgPriceEnabledNotifier.addListener(_syncCanSubmit);
    _transportModeNotifier.addListener(_syncCanSubmit);
    _priceOptionNotifier.addListener(_syncCanSubmit);
    _customPriceCtrl.addListener(_syncCanSubmit);
    _pricePerM3Ctrl.addListener(_syncCanSubmit);
    _pricePerM3Ctrl.addListener(_syncPricePerM3ToFormBloc);
    _boatPriceUnitNotifier.addListener(_syncCanSubmit);
    // Un prix custom valide dans une devise peut dépasser le plafond d'une
    // autre (cf. _isPriceValid) : changer de devise doit donc réévaluer
    // canSubmit sans que l'utilisateur retouche le champ prix.
    widget.currencyNotifier.addListener(_syncCanSubmit);
    // Le mobile money n'est proposé qu'en zone CFA (XOF/XAF) : si le
    // voyageur l'avait activé puis change de devise vers une devise hors
    // zone, la bascule doit se remettre à false — sinon la liste envoyée au
    // submit contiendrait MOBILE_MONEY pour un trajet dans une autre devise.
    widget.currencyNotifier.addListener(_onCurrencyChanged);
    // Création : l'avion d'office quand il est seul proposé ; sinon le
    // voyageur choisit à l'étape Mode (« Continuer » grisé d'ici là).
    if (!_isEdit && !_isLocked) {
      _transportModeNotifier.value = _hasModeStep ? null : TransportMode.plane;
    }
    // Ligne « Mode de transport » (modification, trajet dédié à mode connu) :
    // même règle que l'écran des modèles. Un voyageur qui n'a que l'avion
    // n'a rien à choisir, la ligne n'apparaît que pour un trajet d'un autre
    // mode. Décidé une fois : changer de puce ne la fait pas disparaître.
    _showModeRow =
        (_isEdit || (_isLocked && !_hasModeStep)) &&
        (widget.tripModes.length > 1 ||
            transportModeOrPlane(_transportModeNotifier.value) !=
                TransportMode.plane);
    _syncCanSubmit(); // état initial — transport + prix

    // Désactivation du bouton Continuer tant que les 3 champs obligatoires
    // de l'étape 0 ne sont pas renseignés.
    _departureCityNotifier.addListener(_updateCanContinue);
    _arrivalCityNotifier.addListener(_updateCanContinue);
    _departureDateNotifier.addListener(_updateCanContinue);
    _departureTimeNotifier.addListener(_updateCanContinue);
    _transportModeNotifier.addListener(_updateCanContinue);
    _handoverDeadlineNotifier.addListener(_updateCanContinue);
    _boatArrivalMinNotifier.addListener(_updateCanContinue);
    _boatArrivalMaxNotifier.addListener(_updateCanContinue);
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
    _arrivalDayOffsetNotifier.addListener(_markStep0Touched);
    // Le mode choisi à l'étape Mode n'est pas une saisie de l'étape Trajet :
    // sans cette garde, Trajet s'ouvrait tout en rouge juste après le choix.
    if (!_hasModeStep) _transportModeNotifier.addListener(_markStep0Touched);
    _handoverDeadlineNotifier.addListener(_markStep0Touched);
    _boatArrivalMinNotifier.addListener(_markStep0Touched);
    _boatArrivalMaxNotifier.addListener(_markStep0Touched);

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
    // Recalcule la date limite de dépôt d'un modèle appliqué (délai en jours
    // avant départ) dès que la date de départ change, tant que l'utilisateur
    // n'a pas choisi lui-même un jour limite (cf. _applyTemplate,
    // _applyPendingHandoverLead, _selectHandoverDeadline).
    _departureDateNotifier.addListener(_applyPendingHandoverLead);
    _priceOptionNotifier.addListener(_syncPriceToFormBloc);
    _customPriceNotifier.addListener(_syncPriceToFormBloc);
    _availableKgNotifier.addListener(_syncKgToFormBloc);
    _descriptionCtrl.addListener(_syncDescriptionToFormBloc);
    _transportModeNotifier.addListener(_syncTransportModeToFormBloc);
    _transportModeNotifier.addListener(_clampArrivalOffsetToMode);
    // Modification et trajet dédié : le mode est posé avant ce listener. Le
    // bloc doit le connaître (valises, plafond de capacité, taille max).
    if (_isEdit || _isLocked) _syncTransportModeToFormBloc();
    _cashEnabledNotifier.addListener(_syncCashAcceptedToFormBloc);
    _mobileMoneyEnabledNotifier.addListener(_syncMobileMoneyAcceptedToFormBloc);
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
    if (_isBoat &&
        (_boatArrivalMinNotifier.value == null ||
            _boatArrivalMaxNotifier.value == null))
      _Step0Field.boatArrival,
  };

  void _updateCanContinue() {
    final missing = _missingStep0Fields;
    widget.canContinueNotifier?.value =
        missing.isEmpty &&
        !_isHandoverDeadlineInvalid() &&
        _boatArrivalIssue() == null &&
        !_lockedBoatBlocked;
    _refreshStep0Errors(missing);
  }

  /// Incohérence de l'arrivée estimée d'un bateau (miroir de
  /// `ArrivalRules.validateRange` et de `validate` du back), `null` si elle
  /// est correcte ou incomplète (l'incomplet relève des champs obligatoires).
  /// Fonction pure, sans texte, comme [_isHandoverDeadlineInvalid].
  _BoatArrivalIssue? _boatArrivalIssue() {
    if (!_isBoat) return null;
    final min = _boatArrivalMinNotifier.value;
    final max = _boatArrivalMaxNotifier.value;
    final departure = _departureDateNotifier.value;
    if (min != null &&
        departure != null &&
        DateUtils.dateOnly(min).isBefore(DateUtils.dateOnly(departure))) {
      return _BoatArrivalIssue.beforeDeparture;
    }
    if (min != null && max != null && max.isBefore(min)) {
      return _BoatArrivalIssue.latestBeforeEarliest;
    }
    if (max != null &&
        departure != null &&
        DateUtils.dateOnly(max).isAfter(_boatArrivalLimit(departure))) {
      return _BoatArrivalIssue.tooFar;
    }
    return null;
  }

  /// Dernier jour d'arrivée possible d'un bateau parti le jour [departure].
  static DateTime _boatArrivalLimit(DateTime departure) => DateTime(
    departure.year,
    departure.month,
    departure.day + TransportMode.boat.maxArrivalDays,
  );

  /// Message sous l'arrivée estimée d'un bateau : l'incohérence d'abord, puis
  /// l'arrivée manquante une fois l'étape touchée.
  String? _boatArrivalMessage(AppLocalizations l10n) {
    final issue = _boatArrivalIssue();
    if (issue != null) return _boatArrivalIssueMessage(l10n, issue);
    return _step0ErrorsNotifier.value.contains(_Step0Field.boatArrival)
        ? _step0FieldMessage(l10n, _Step0Field.boatArrival)
        : null;
  }

  static String _boatArrivalIssueMessage(
    AppLocalizations l10n,
    _BoatArrivalIssue issue,
  ) => switch (issue) {
    _BoatArrivalIssue.beforeDeparture =>
      l10n.tripPublishBoatArrivalBeforeDeparture,
    _BoatArrivalIssue.latestBeforeEarliest =>
      l10n.tripPublishBoatArrivalLatestBeforeEarliest,
    _BoatArrivalIssue.tooFar => l10n.tripPublishBoatArrivalTooFar(
      TransportMode.boat.maxArrivalDays,
    ),
  };

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
  static String? _msg(
    AppLocalizations l10n,
    Set<_Step0Field> missing,
    _Step0Field f,
  ) => missing.contains(f) ? _step0FieldMessage(l10n, f) : null;

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
    _arrivalDayOffsetNotifier,
    _handoverDeadlineNotifier,
    _boatArrivalMinNotifier,
    _boatArrivalMaxNotifier,
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
    _cardEnabledNotifier,
    _mobileMoneyEnabledNotifier,
    _stopsNotifier,
    _negotiableNotifier,
    _kgPriceEnabledNotifier,
    _descriptionCtrl,
    _customAcceptedCtrl,
    _refusedCtrl,
    _customPriceCtrl,
    _pricePerM3Ctrl,
    _boatPriceUnitNotifier,
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
      _arrivalDayOffsetNotifier.value,
      _handoverDeadlineNotifier.value,
      _boatArrivalMinNotifier.value,
      _boatArrivalMaxNotifier.value,
      _pickupAddressNotifier.value?.label,
      _deliveryAddressNotifier.value?.label,
      _availableKgNotifier.value,
      _priceOptionNotifier.value,
      _customPriceNotifier.value,
      _transportModeNotifier.value,
      _cashEnabledNotifier.value,
      _cardEnabledNotifier.value,
      _mobileMoneyEnabledNotifier.value,
      _stopsNotifier.value,
      _negotiableNotifier.value,
      _kgPriceEnabledNotifier.value,
      set(_selectedContentNotifier.value),
      set(_customAcceptedNotifier.value),
      set(_refusedTypesNotifier.value),
      _descriptionCtrl.text,
      _customAcceptedCtrl.text,
      _refusedCtrl.text,
      _customPriceCtrl.text,
      _pricePerM3Ctrl.text,
      _boatPriceUnitNotifier.value?.wire,
      // Volume d'un bateau : porté par le bloc (étape Capacité).
      context.read<AnnouncementFormBloc>().state.volumeCapacityM3,
    ].join('|');
  }

  /// Référence de comparaison. Nulle tant que la première frame n'a pas été
  /// rendue : voir `_captureInitialSignature`.
  String? _initialFormSignature;

  /// Formulaire rechargé depuis un brouillon local : il compte comme entamé,
  /// la sortie doit proposer de garder ou de supprimer ce brouillon.
  bool _restoredFromDraft = false;

  void _markDirty() {
    if (_initialFormSignature == null) return;
    final dirty = _restoredFromDraft || _formSignature != _initialFormSignature;
    if (widget.dirtyNotifier != null && widget.dirtyNotifier!.value != dirty) {
      widget.dirtyNotifier!.value = dirty;
    }
  }

  /// Reprend la référence une fois la première frame passée.
  ///
  /// Certains champs sont positionnés par l'application elle-même, pas par
  /// l'utilisateur, et seulement une fois l'arbre construit : `PrixStep`
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
    if (_step1Touched ||
        widget.currentStepNotifier?.value != TripFormStep.capacite) {
      return;
    }
    _step1Touched = true;
    _updateCanContinueStep1();
  }

  void _updateCanContinueStep1() {
    // Capacité au-delà du plafond du mode ou poids max par colis hors bornes :
    // « Continuer » grisé (Review Focus 4). Trajet dédié : capacité fixée par
    // la demande, rien à vérifier ici.
    final capacityValid =
        _isLocked ||
        context.read<AnnouncementFormBloc>().state.isCapacityStepValid;
    widget.canContinueStep1Notifier?.value =
        _pickupAddress != null && _deliveryAddress != null && capacityValid;
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

  /// « Continuer » de l'étape Prix et bouton final de l'étape Conditions :
  /// même règle, mode choisi et prix valide.
  void _syncCanSubmit() {
    final ready = _transportModeNotifier.value != null && _isPriceValid;
    widget.canContinuePriceNotifier?.value = ready;
    widget.canSubmitNotifier?.value = ready;
  }

  /// Valide les champs obligatoires de l'étape 0 (Trajet).
  /// Affiche un snackbar d'erreur si un champ manque et retourne false.
  /// Vrai si la date limite de dépôt saisie est postérieure au départ,
  /// faux si elle est correcte (ou pas encore renseignée).
  ///
  /// Fonction pure, sans texte : appelée depuis `_updateCanContinue()` (donc
  /// potentiellement depuis `initState()`, où dépendre d'un `Localizations`
  /// via `context.l10n` lève « dependOnInheritedWidgetOfExactType() was
  /// called before initState() completed »). Le message localisé n'est
  /// résolu qu'à l'affichage, dans l'`AnimatedBuilder` qui le montre — seul
  /// endroit qui a besoin de se réabonner à `Localizations` pour rester
  /// réactif à un changement de langue à chaud.
  bool _isHandoverDeadlineInvalid() {
    final deadline = _resolveHandoverDeadline();
    if (deadline == null) return false;
    final bound = _departureBound();
    if (bound == null) return false;
    return deadline.isAfter(bound);
  }

  /// Instant du départ, même calcul qu'à l'envoi : jour et heure de départ.
  /// Sans heure de départ, la fin du jour du départ : seul le jour se
  /// compare alors.
  DateTime? _departureBound() {
    final date = _departureDateNotifier.value;
    if (date == null) return null;
    final time = _departureTimeNotifier.value;
    return time == null
        ? DateTime(date.year, date.month, date.day, 23, 59, 59)
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static bool _hasTime(DateTime d) => d.hour != 0 || d.minute != 0;

  /// Date limite d'une annonce modifiée, en heure locale. Celle qui tombait
  /// pile à l'heure de départ (règle d'avant FLUTTER-PK) redevient un jour
  /// sans heure : elle suit encore l'heure de départ si celle-ci change.
  static DateTime? _initialEditHandoverDeadline(AnnouncementModel a) {
    final deadline = a.handoverDeadline?.toLocal();
    if (deadline == null) return null;
    final time = a.departureTime;
    final atDeparture =
        DateUtils.isSameDay(deadline, a.departureDate) &&
        time != null &&
        time.length >= 5 &&
        '${deadline.hour.toString().padLeft(2, '0')}:'
                '${deadline.minute.toString().padLeft(2, '0')}' ==
            time.substring(0, 5);
    return atDeparture ? DateUtils.dateOnly(deadline) : deadline;
  }

  /// Instant envoyé au backend.
  ///
  /// L'heure choisie par le voyageur est gardée telle quelle (FLUTTER-PK) :
  /// postérieure au départ, elle est signalée par
  /// [_isHandoverDeadlineInvalid] au lieu d'être corrigée en silence. Un jour
  /// sans heure (minuit : modèle appliqué `handoverLeadDays`, ancien
  /// brouillon, heure annulée) se borne à la fin de journée, sauf le jour du
  /// départ où la limite devient l'heure de départ : le backend refuse toute
  /// date limite postérieure au départ.
  DateTime? _resolveHandoverDeadline() {
    final deadline = _handoverDeadlineNotifier.value;
    if (deadline == null) return null;
    if (_hasTime(deadline)) return deadline;
    return _fallbackHandoverDeadline(deadline);
  }

  /// Heure de repli d'un jour limite choisi sans heure.
  DateTime _fallbackHandoverDeadline(DateTime day) {
    final date = _departureDateNotifier.value;
    final time = _departureTimeNotifier.value;
    if (date != null && time != null && DateUtils.isSameDay(day, date)) {
      return DateTime(day.year, day.month, day.day, time.hour, time.minute);
    }
    return DateTime(day.year, day.month, day.day, 23, 59);
  }

  /// Date limite telle qu'elle partira au serveur, jour et heure.
  String? _handoverDeadlineDisplay(AppLocalizations l) {
    final resolved = _resolveHandoverDeadline();
    if (resolved == null) return null;
    return l.commonDateAtTime(
      DateFormat.MMMd(l.localeName).format(resolved),
      DateFormat.jm(l.localeName).format(resolved),
    );
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
    context.read<AnnouncementFormBloc>().add(
      PriceChanged(_pricePerKg, currency: _currency),
    );
  }

  /// Vrai le temps que le `BlocListener` recopie `state.availableKg` dans
  /// `_availableKgNotifier` : cette écriture vient du bloc, la lui renvoyer
  /// serait un écho. Sans cette garde, `_applyTemplate` laisse deux valeurs
  /// différentes en file (le maxKg de l'unité, puis le kg du modèle) qui se
  /// relancent l'une l'autre sans fin — une boucle de microtâches où les
  /// timers ne tournent jamais, donc que `--timeout` ne coupe pas.
  bool _applyingKgFromBloc = false;

  /// Une seule source de vérité au démarrage d'une création : le kg du
  /// notifier (défaut, ou poids d'un trajet dédié) part tout de suite dans le
  /// bloc, que le compteur de valises affiche. Sans cet envoi, le bloc restait
  /// à `null` (compteur sur 23 kg) et la soumission envoyait le défaut du
  /// notifier (15 kg, YADONY-FLUTTER-PROD-18).
  ///
  /// Appelé en `initState`, avant tout préremplissage (modèle, brouillon,
  /// assistant) : leurs événements sont ajoutés après, et l'emportent.
  void _seedAvailableKgToFormBloc() {
    final bloc = context.read<AnnouncementFormBloc>();
    if (bloc.state.availableKg != null) return;
    bloc.add(AvailableKgChanged(_availableKgNotifier.value));
  }

  /// Kg envoyés au serveur. En création libre avec une unité valise, ramenés
  /// à un nombre entier de valises : le compteur ne montre jamais autre chose.
  /// L'édition garde le kg du trajet, qui baisse à chaque réservation ; le
  /// trajet dédié garde le poids fixé par la demande.
  /// Réservé aux tests : kg que la création enverrait, lu comme
  /// [handoverDeadlineForTest] via le `Key` de `_TripFormContent`.
  @visibleForTesting
  double get availableKgToSubmitForTest => _availableKgToSubmit;

  double get _availableKgToSubmit {
    final kg = _availableKgNotifier.value;
    if (_isEdit || _isLocked) return kg;
    return context.read<AnnouncementFormBloc>().state.capacityUnit.normalizeKg(
      kg,
    );
  }

  void _syncKgToFormBloc() {
    if (!mounted || _applyingKgFromBloc) return;
    final bloc = context.read<AnnouncementFormBloc>();
    if (bloc.state.availableKg == _availableKgNotifier.value) return;
    bloc.add(AvailableKgChanged(_availableKgNotifier.value));
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
      final bloc = context.read<AnnouncementFormBloc>();
      bloc.add(TransportModeChanged(mode));
      // Trajet dédié bateau : formulaire d'avant le lot 3 (tâche A10).
      if (mode == TransportMode.boat && !_isLocked) {
        // Vendu au m³ par défaut (groupage en conteneur), tant que rien
        // n'est choisi (modification, brouillon : l'unité du trajet).
        final unit = _boatPriceUnitNotifier.value ??= BoatPriceUnit.m3;
        bloc.add(BoatPriceUnitChanged(unit));
        // Pas de grille en bateau (422 `boat-price-required`) : retour au
        // prix au kilo, jamais une grille cachée envoyée.
        if (bloc.state.pricingMode == PricingMode.mixed) {
          bloc.add(const AnnouncementPricingModeSetRequested(PricingMode.kg));
        }
      }
    }
  }

  void _syncPricePerM3ToFormBloc() {
    if (!mounted) return;
    context.read<AnnouncementFormBloc>().add(
      PricePerM3Changed(parsePriceInput(_pricePerM3Ctrl.text)),
    );
  }

  /// Texte de saisie d'un prix relu (point décimal, deux décimales au plus).
  static String _priceInputText(double price) =>
      NumberFormat('#0.##', 'en').format(price);

  void _syncCashAcceptedToFormBloc() {
    if (!mounted) return;
    context.read<AnnouncementFormBloc>().add(
      CashAcceptedChanged(_cashEnabledNotifier.value),
    );
  }

  void _syncMobileMoneyAcceptedToFormBloc() {
    if (!mounted) return;
    context.read<AnnouncementFormBloc>().add(
      MobileMoneyAcceptedChanged(_mobileMoneyEnabledNotifier.value),
    );
  }

  /// Remet la bascule mobile money à `false` quand la devise quitte la zone
  /// CFA (XOF/XAF). Ne fait rien si elle y reste ou y entre — seule la
  /// sortie de zone doit désactiver un choix devenu invalide.
  ///
  /// Resynchronise aussi le prix vers le bloc : l'index de chip est conservé
  /// mais désigne un autre montant dans la nouvelle devise, et la fourchette
  /// d'alerte change avec elle.
  void _onCurrencyChanged() {
    if (!widget.currencyNotifier.value.isMobileMoneyEligible) {
      _mobileMoneyEnabledNotifier.value = false;
    }
    _resetPricePerM3OnCurrencyChange();
    _syncPriceToFormBloc();
  }

  /// Devise posée par un modèle ou un brouillon : son prix au m³ arrive juste
  /// après, dans la bonne devise, rien à ressaisir.
  bool _currencyFromSnapshot = false;

  void _setCurrencyFromSnapshot(SupportedCurrency currency) {
    _currencyFromSnapshot = true;
    try {
      widget.currencyNotifier.value = currency;
    } finally {
      _currencyFromSnapshot = false;
    }
  }

  /// Prix au m³ saisi dans l'ancienne devise : jamais gardé tel quel
  /// (65 600 F CFA devenaient 65 600 €/m³, recette du 14/11). Le champ est
  /// vidé et, s'il était affiché, un message demande de le ressaisir dans la
  /// nouvelle devise.
  void _resetPricePerM3OnCurrencyChange() {
    if (_currencyFromSnapshot || _pricePerM3Ctrl.text.trim().isEmpty) return;
    final visible = _isBoatPerM3;
    _pricePerM3Ctrl.clear();
    if (!visible || !mounted) return;
    DonySnackbar.show(
      context,
      message: context.l10n.tripPublishPerM3CurrencyReset(
        widget.currencyNotifier.value.symbol,
      ),
      type: DonySnackbarType.warning,
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
    _boatArrivalMinNotifier.removeListener(_updateCanContinue);
    _boatArrivalMaxNotifier.removeListener(_updateCanContinue);
    _departureCityNotifier.removeListener(_syncCityToFormBloc);
    _arrivalCityNotifier.removeListener(_syncCityToFormBloc);
    _departureDateNotifier.removeListener(_syncDateToFormBloc);
    _departureDateNotifier.removeListener(_applyPendingHandoverLead);
    _priceOptionNotifier.removeListener(_syncPriceToFormBloc);
    _customPriceNotifier.removeListener(_syncPriceToFormBloc);
    _availableKgNotifier.removeListener(_syncKgToFormBloc);
    _descriptionCtrl.removeListener(_syncDescriptionToFormBloc);
    // Notifier porté par l'écran, qui survit à ce State : tous ses
    // listeners partent ici.
    _transportModeNotifier.removeListener(_syncCanSubmit);
    _transportModeNotifier.removeListener(_syncTransportModeToFormBloc);
    _transportModeNotifier.removeListener(_clampArrivalOffsetToMode);
    _transportModeNotifier.removeListener(_updateCanContinue);
    _transportModeNotifier.removeListener(_markStep0Touched);
    _cashEnabledNotifier.removeListener(_syncCashAcceptedToFormBloc);
    _mobileMoneyEnabledNotifier.removeListener(
      _syncMobileMoneyAcceptedToFormBloc,
    );
    _selectedContentNotifier.removeListener(_syncAcceptedTypesToFormBloc);
    _customAcceptedNotifier.removeListener(_syncAcceptedTypesToFormBloc);
    _refusedTypesNotifier.removeListener(_syncRejectedTypesToFormBloc);
    _departureTimeNotifier.removeListener(_syncDepartureTimeToParent);
    _kgPriceEnabledNotifier.removeListener(_onKgToggleChanged);
    _kgPriceEnabledNotifier.removeListener(_syncCanSubmit);
    _priceOptionNotifier.removeListener(_syncCanSubmit);
    _customPriceCtrl.removeListener(_syncCanSubmit);
    _pricePerM3Ctrl.removeListener(_syncCanSubmit);
    _pricePerM3Ctrl.removeListener(_syncPricePerM3ToFormBloc);
    _boatPriceUnitNotifier.removeListener(_syncCanSubmit);
    widget.currencyNotifier.removeListener(_syncCanSubmit);
    widget.currencyNotifier.removeListener(_onCurrencyChanged);
    _kgPriceEnabledNotifier.dispose();
    _cashEnabledNotifier.dispose();
    _cardEnabledNotifier.dispose();
    _stopsNotifier.dispose();
    _mobileMoneyEnabledNotifier.dispose();
    _negotiableNotifier.dispose();
    _descriptionCtrl.dispose();
    _customAcceptedCtrl.dispose();
    _refusedCtrl.dispose();
    _customPriceCtrl.dispose();
    _pricePerM3Ctrl.dispose();
    _boatPriceUnitNotifier.dispose();
    _customPriceNotifier.dispose();
    _departureCityNotifier.dispose();
    _arrivalCityNotifier.dispose();
    _departureCountryCodeNotifier.dispose();
    _arrivalCountryCodeNotifier.dispose();
    _departureDateNotifier.dispose();
    _departureTimeNotifier.dispose();
    _arrivalTimeNotifier.dispose();
    _arrivalDayOffsetNotifier.dispose();
    _boatArrivalMinNotifier.dispose();
    _boatArrivalMaxNotifier.dispose();
    _handoverDeadlineNotifier.dispose();
    _availableKgNotifier.dispose();
    _priceOptionNotifier.dispose();
    _selectedContentNotifier.dispose();
    _customAcceptedNotifier.dispose();
    _catalogLabelsNotifier.dispose();
    _refusedTypesNotifier.dispose();
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

  /// Moyens de paiement envoyés au submit, et affichés tels quels par l'aperçu
  /// (FLUTTER-GJ).
  ///
  /// Publiable sans Stripe (cash-only) : STRIPE n'est inclus que si
  /// configuré, et CASH est forcé quand Stripe ne l'est pas — la liste ne
  /// peut jamais être vide (au moins une méthode de paiement est requise).
  /// La carte n'existe pas en zone CFA (pas de Stripe Connect) : elle n'est
  /// envoyée que si la devise du trajet l'autorise, comme l'aperçu du
  /// sélecteur de devise. Le backend la retirerait de toute façon.
  /// La carte est décochable (FLUTTER-FT) : sans elle, les espèces
  /// repartent d'office, comme quand Stripe n'est pas configuré.
  /// Dates de l'aperçu (cf. [TripPreviewDates]) : la fourchette d'arrivée
  /// seulement en bateau, la date limite de dépôt dès qu'elle est saisie.
  TripPreviewDates _previewDates() => (
    arrivalMin: _isBoat ? _boatArrivalMinNotifier.value : null,
    arrivalMax: _isBoat ? _boatArrivalMaxNotifier.value : null,
    handoverDeadline: _resolveHandoverDeadline(),
  );

  List<String> _paymentMethods() {
    final stripeConfigured =
        _isStripeConfigured() && _currency.isStripeEligible;
    final cardOn = stripeConfigured && _cardEnabledNotifier.value;
    return [
      if (cardOn) 'STRIPE',
      if (_cashEnabledNotifier.value || !cardOn) 'CASH',
      if (_mobileMoneyEnabledNotifier.value) 'MOBILE_MONEY',
    ];
  }

  /// Moyens de paiement possibles pour une étape ajoutée (FLUTTER-HP), lus à
  /// l'ouverture de sa feuille : le voyageur y coche lui-même les siens.
  TripLegPaymentRails _legPaymentRails() {
    final mobileMoneyState = context.read<MobileMoneyAccountBloc>().state;
    return TripLegPaymentRails(
      stripeConfigured: _isStripeConfigured(),
      mobileMoneyAccountActive: mobileMoneyAccountActiveFrom(mobileMoneyState),
      mobileMoneyAccountCurrencies: mobileMoneyAccountCurrenciesFrom(
        mobileMoneyState,
      ),
    );
  }

  /// Devises des étapes ajoutées, dans l'ordre du voyage (FLUTTER-HP).
  List<SupportedCurrency> _extraLegCurrencies() => [
    for (final leg in context.read<TripLegsCubit>().state.legs)
      TripLegCurrency.of(leg, _currency),
  ];

  /// La question « Vous voyagez en tant que ? » a déjà été montrée (ou le
  /// voyageur y a répondu) pour cette publication : on ne la remontre pas.
  bool _travelerStatusReminded = false;

  /// La question du statut est en cours (lecture de la demande GP Pro puis
  /// feuille) : verrou de ré-entrance, sans `setState`.
  bool _reminding = false;

  /// Question du statut avant la publication d'un nouveau trajet. Jamais pour
  /// un brouillon, une modification ou un trajet dédié à une demande. Fermée
  /// d'un « Plus tard », ou après l'envoi d'une demande GP Pro (le voyageur
  /// publie comme particulier pendant la validation), la publication continue.
  /// Un formulaire GP Pro quitté sans envoyer la demande ne publie rien et ne
  /// dit rien : le voyageur retrouve son formulaire, la question reviendra.
  Future<void> _remindTravelerStatusThenSubmit() async {
    // Verrou posé dès l'appui, avant la lecture de la demande GP Pro : un second
    // appui sur « Publier » pendant l'attente n'ouvre pas une deuxième feuille.
    if (_reminding) return;
    _reminding = true;
    final TravelerStatusOutcome? outcome;
    try {
      outcome = await remindTravelerStatusBeforePublish(context);
    } finally {
      _reminding = false;
    }
    if (!mounted || outcome == TravelerStatusOutcome.gpProAbandoned) return;
    _travelerStatusReminded = true;
    _submit();
  }

  /// Publication refusée par la limite mensuelle (403 `traveler-status-required`,
  /// `monthly-limit-reached` ou `gp-pro-pending`) : l'écran de blocage s'ouvre.
  /// Si plus rien ne bloque au retour, la publication reprend ; sinon le
  /// voyageur retrouve son formulaire, qu'il peut enregistrer en brouillon.
  Future<void> _onPublishingBlocked(PublishingReason reason) async {
    final canPublish = await showPublishingBlocked(context, reason);
    if (!canPublish || !mounted) return;
    _travelerStatusReminded = true;
    _submit();
  }

  /// Vrai quand le serveur a confirmé VERIFIED alors que le profil en cache
  /// disait le contraire : le gate d'identité est franchi sans attendre que
  /// l'AuthBloc ait publié le profil resynchronisé.
  bool _kycRecheckedVerified = false;

  /// Le cache dit « identité non vérifiée » : on relit le serveur avant de
  /// bloquer (validation faite hors de l'app, sans push).
  Future<void> _recheckKycThenSubmit() async {
    final verified = await recheckKycVerified(context.read<AuthBloc>());
    if (!mounted) return;
    if (verified) {
      _kycRecheckedVerified = true;
      _submit();
      return;
    }
    unawaited(KycOnboardingBottomSheet.show(context));
  }

  void _submit({bool saveAsDraft = false}) {
    // Gate KYC — inchangé pour le reste du flux, nouveau uniquement ici :
    // publier/modifier un trajet nécessite une identité vérifiée. Si ce n'est
    // pas le cas, on ouvre l'onboarding KYC au lieu d'appeler l'API.
    final user = context.read<AuthBloc>().state.currentUser;
    if (!saveAsDraft &&
        !_kycRecheckedVerified &&
        user != null &&
        !user.isKycVerified) {
      unawaited(_recheckKycThenSubmit());
      return;
    }
    if (!saveAsDraft &&
        !_isEdit &&
        !_isLocked &&
        !_travelerStatusReminded &&
        travelerStatusMissing(context)) {
      unawaited(_remindTravelerStatusThenSubmit());
      return;
    }

    final departureCity = _departureCityNotifier.value;
    final arrivalCity = _arrivalCityNotifier.value;
    final departureDate = _departureDateNotifier.value;
    final departureTimeVal = _departureTimeNotifier.value;
    final arrivalTimeVal = _arrivalTimeNotifier.value;

    if (departureCity == null) {
      _showError(_step0FieldMessage(context.l10n, _Step0Field.departureCity));
      return;
    }
    if (arrivalCity == null) {
      _showError(_step0FieldMessage(context.l10n, _Step0Field.arrivalCity));
      return;
    }
    if (departureDate == null) {
      _showError(_step0FieldMessage(context.l10n, _Step0Field.departureDate));
      return;
    }
    // D1 : l'heure de départ est obligatoire (backstop du verrou d'annulation).
    if (departureTimeVal == null) {
      _showError(_step0FieldMessage(context.l10n, _Step0Field.departureTime));
      return;
    }

    _formKey.currentState!.save();

    if (_pickupAddress == null) {
      _showError(_step1FieldMessage(context.l10n, _Step1Field.pickupAddress));
      return;
    }
    if (_deliveryAddress == null) {
      _showError(_step1FieldMessage(context.l10n, _Step1Field.deliveryAddress));
      return;
    }
    if (_transportModeNotifier.value == null) {
      _showError(_step0FieldMessage(context.l10n, _Step0Field.transportMode));
      return;
    }

    // departureTimeVal est garanti non-null par le guard plus haut (heure de
    // départ obligatoire — tranche A).
    final departureTime = _formatTime(departureTimeVal);
    final arrivalTime = arrivalTimeVal != null
        ? _formatTime(arrivalTimeVal)
        : null;
    // Bateau : la fourchette d'arrivée estimée, toujours envoyée. Ailleurs,
    // l'arrivée seulement si elle tombe un autre jour que le départ.
    final String? arrivalDate;
    String? arrivalDateMax;
    if (_isBoat) {
      final min = _boatArrivalMinNotifier.value;
      final max = _boatArrivalMaxNotifier.value;
      if (min == null || max == null) {
        _showError(_step0FieldMessage(context.l10n, _Step0Field.boatArrival));
        return;
      }
      final issue = _boatArrivalIssue();
      if (issue != null) {
        _showError(_boatArrivalIssueMessage(context.l10n, issue));
        return;
      }
      arrivalDate = DateFormat('yyyy-MM-dd').format(min);
      arrivalDateMax = DateFormat('yyyy-MM-dd').format(max);
    } else {
      final arrivalOffset = _effectiveArrivalOffset();
      arrivalDate = arrivalOffset > 0
          ? DateFormat('yyyy-MM-dd').format(
              DateUtils.dateOnly(
                departureDate,
              ).add(Duration(days: arrivalOffset)),
            )
          : null;
    }

    final allAccepted = acceptedContentWithPrecision(
      selected: _selectedContentNotifier.value,
      custom: _customAcceptedNotifier.value,
      otherPrecision: _customAcceptedCtrl.text,
    );
    if (allAccepted == null) {
      _showError(context.l10n.tripPublishOtherContentPrecisionRequired);
      return;
    }
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
          arrivalDate: arrivalDate,
          pickupAddress: pickupAddress,
          deliveryAddress: deliveryAddress,
          description: description,
          acceptedContentTypes: allAccepted,
          refusedTypes: refused,
          arrivalDateMax: arrivalDateMax,
          paymentMethod: lc.paymentMethod,
          // Envoyé seulement quand le voyageur l'a choisi (demande « peu
          // importe ») : sinon le back garde le mode de la demande.
          transportMode: _hasModeStep ? transportMode : null,
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
          arrivalDate: arrivalDate,
          arrivalDateMax: arrivalDateMax,
          pickupAddress: pickupAddress,
          deliveryAddress: deliveryAddress,
          description: description,
          acceptedContentTypes: allAccepted,
          refusedTypes: refused,
          transportMode: _hasModeStep ? transportMode : null,
        ),
      );
      // Distingue ce flux de celui à thread existant au retour du bloc.
      _lastStartWithDedicatedTripEvent = startEvent;
      context.read<NegotiationBloc>().add(startEvent);
      return;
    }

    final paymentMethods = _paymentMethods();
    // Escales : avion seulement, sinon jamais envoyées.
    final stops = supportsStops(transportMode) ? _stopsNotifier.value : null;

    final formBlocState = context.read<AnnouncementFormBloc>().state;
    // Bateau au m³ : volume et prix au m³, aucun kilo (ni capacité, ni prix
    // au kilo, ni unité de capacité).
    final perM3 = transportMode == TransportMode.boat && _isBoatPerM3;
    if (perM3 && !formBlocState.isVolumeValid) {
      _showError(context.l10n.tripPublishBoatVolumeInvalid);
      return;
    }
    if (formBlocState.capacityTooHigh) {
      _showError(
        context.l10n.tripPublishCapacityTooHigh(
          formatWeightKg(context.l10n, formBlocState.capacityMaxKg.toDouble()),
        ),
      );
      return;
    }
    if (!formBlocState.isMaxParcelWeightValid) {
      _showError(context.l10n.tripPublishMaxParcelWeightInvalid);
      return;
    }
    // Taille max d'un colis en route, poids max par colis en route et en
    // bateau : jamais un champ caché.
    final hasItemSize = transportMode.hasItemSize;
    final hasMaxParcelWeight = transportMode.hasMaxParcelWeight;
    final maxItemSize = hasItemSize ? formBlocState.maxItemSize : null;
    final maxParcelWeightKg = hasMaxParcelWeight
        ? formBlocState.maxParcelWeightKg
        : null;
    final capacityUnitWire = perM3 ? null : formBlocState.capacityUnit.toWire();
    // Pas de grille en bateau.
    final pricingModeWire =
        formBlocState.pricingMode == PricingMode.mixed &&
            transportMode != TransportMode.boat
        ? 'MIXED'
        : 'KG';
    final double? pricePerKgToSubmit = perM3
        ? null
        : formBlocState.pricePerKg ?? 0.0;
    final volumeCapacityM3 = perM3 ? formBlocState.volumeCapacityM3 : null;
    final pricePerM3 = perM3 ? parsePriceInput(_pricePerM3Ctrl.text) : null;

    final handoverDeadline = _resolveHandoverDeadline();
    if (handoverDeadline == null) {
      _showError(
        _step0FieldMessage(context.l10n, _Step0Field.handoverDeadline),
      );
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
      _showError(context.l10n.tripPublishHandoverDeadlineBeforeDeparture);
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
          arrivalDate: arrivalDate,
          pickupAddress: _pickupAddress!,
          deliveryAddress: _deliveryAddress!,
          availableKg: perM3 ? null : _availableKgNotifier.value,
          pricePerKg: pricePerKgToSubmit,
          transportMode: transportMode,
          arrivalDateMax: arrivalDateMax,
          volumeCapacityM3: volumeCapacityM3,
          pricePerM3: pricePerM3,
          stops: stops,
          description: description,
          acceptedContentTypes: allAccepted,
          refusedTypes: refused,
          acceptedPaymentMethods: paymentMethods,
          capacityUnit: capacityUnitWire,
          pricingMode: pricingModeWire,
          handoverDeadline: handoverDeadline,
          negotiable: _negotiableNotifier.value,
          // Envoyée seulement si elle a changé sur un trajet encore
          // modifiable : absente, le serveur garde la devise (FLUTTER-KV).
          currency:
              _isEditCurrencyEditable &&
                  _currency.code != widget.announcement!.currency
              ? _currency.code
              : null,
          // Envoyés seulement si le voyageur les a changés : absents, le
          // serveur les garde ; effacés, il reçoit la sentinelle.
          maxItemSize: _editChange(
            maxItemSize,
            widget.announcement!.maxItemSize,
            hasItemSize,
          ),
          maxParcelWeightKg: _editChange(
            maxParcelWeightKg,
            widget.announcement!.maxParcelWeightKg,
            hasMaxParcelWeight,
          ),
        ),
      );
    } else {
      final createEvent = AnnouncementCreateRequested(
        departureCity: departureCity,
        arrivalCity: arrivalCity,
        departureCountryCode: formBlocState.departureCountryCode,
        arrivalCountryCode: formBlocState.arrivalCountryCode,
        departureDate: departureDate,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        arrivalDate: arrivalDate,
        pickupAddress: _pickupAddress!,
        deliveryAddress: _deliveryAddress!,
        availableKg: perM3 ? null : _availableKgToSubmit,
        pricePerKg: pricePerKgToSubmit,
        transportMode: transportMode,
        arrivalDateMax: arrivalDateMax,
        volumeCapacityM3: volumeCapacityM3,
        pricePerM3: pricePerM3,
        stops: stops,
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
        fromAi: context.read<AiFilledFieldsCubit>().isFromAi,
        maxItemSize: maxItemSize,
        maxParcelWeightKg: maxParcelWeightKg,
      );
      // Voyage à plusieurs étapes (FLUTTER-4D) : toutes les étapes partent
      // ensemble, en une transaction côté serveur. Jamais en bateau, qui n'a
      // ni escales ni étapes (section masquée).
      final extraLegs = transportMode == TransportMode.boat
          ? const <TripLegDraft>[]
          : context.read<TripLegsCubit>().state.legs;
      if (extraLegs.isEmpty) {
        context.read<AnnouncementBloc>().add(createEvent);
        return;
      }
      SupportedCurrency legCurrency(int i) =>
          TripLegCurrency.of(extraLegs[i], _currency);
      // Une étape au-dessus du plafond de sa devise serait refusée par le
      // serveur (FLUTTER-GK) ; chaque étape a sa devise (FLUTTER-HP).
      final aboveMax = TripLegsSection.priceAboveMaxIndexes(
        extraLegs,
        _currency,
      );
      if (aboveMax.isNotEmpty) {
        _showError(
          context.l10n.tripLegsPriceAboveMax(
            legCurrency(aboveMax.first).symbol,
          ),
        );
        return;
      }
      // Même règle pour le plancher : une étape à 8 XOF/kg est partie ainsi.
      final belowMin = TripLegsSection.priceBelowMinIndexes(
        extraLegs,
        _currency,
      );
      if (belowMin.isNotEmpty) {
        _showError(
          context.l10n.tripLegsPriceBelowMin(
            legCurrency(belowMin.first).symbol,
          ),
        );
        return;
      }
      // Tarification au kilo : une étape sans prix dans une autre devise que
      // le premier trajet n'en reçoit pas de copie (FLUTTER-HP).
      if (pricingModeWire == 'KG' &&
          TripLegsSection.priceMissingIndexes(
            extraLegs,
            _currency,
          ).isNotEmpty) {
        _showError(context.l10n.tripLegsPriceMissing);
        return;
      }
      // Chaque étape part avec les moyens de paiement cochés dans sa feuille
      // (FLUTTER-HP).
      final legs = extraLegs;
      final event = AnnouncementTripCreateRequested(
        first: createEvent,
        legs: legs,
      );
      final lines = <TripCurrencyLine>[
        TripCurrencyLine(
          route: '$departureCity → $arrivalCity',
          currency: _currency,
        ),
        for (var i = 0; i < legs.length; i++)
          TripCurrencyLine(
            route:
                '${i == 0 ? arrivalCity : legs[i - 1].arrivalCity} → ${legs[i].arrivalCity}',
            currency: legCurrency(i),
          ),
      ];
      // Plusieurs devises : le voyageur confirme avant la publication, les
      // prix ne sont pas convertis (FLUTTER-HP). Un brouillon se corrige
      // encore : pas de confirmation.
      if (!saveAsDraft && TripCurrenciesConfirmSheet.needed(lines)) {
        unawaited(_confirmCurrenciesThenCreate(lines, event));
        return;
      }
      context.read<AnnouncementBloc>().add(event);
    }
  }

  /// Modification d'un champ facultatif : inchangé tant que la valeur du
  /// formulaire est celle du trajet ouvert, ou que le mode n'en porte pas
  /// (passer en avion efface les deux côté serveur).
  static FieldChange<T> _editChange<T extends Object>(
    T? current,
    T? original,
    bool applies,
  ) {
    if (!applies || current == original) return FieldChange<T>.keep();
    return FieldChange.setOrClear(current);
  }

  Future<void> _confirmCurrenciesThenCreate(
    List<TripCurrencyLine> lines,
    AnnouncementTripCreateRequested event,
  ) async {
    final confirmed = await TripCurrenciesConfirmSheet.show(
      context,
      lines: lines,
    );
    if (!confirmed || !mounted) return;
    context.read<AnnouncementBloc>().add(event);
  }

  void _showError(String message) {
    DonySnackbar.show(context, message: message, type: DonySnackbarType.error);
  }

  /// Ferme le formulaire puis ouvre [location] : `push` par défaut, `go`
  /// avec [replace].
  ///
  /// Le formulaire peut être SEUL dans la pile : l'intro de publication,
  /// atteinte par un `go` (premiers pas de l'accueil), le remplace par
  /// `pushReplacement`. `Navigator.pop(true)` retirait alors la dernière page
  /// (« You have popped the last page off of the stack », pile vide en
  /// release ; même défaut que YADONY-FLUTTER-PROD-2Y/2Z côté demande). Sans
  /// appelant à qui rendre `true`, la destination remplace la pile, et son
  /// bouton retour retombe sur l'accueil.
  void _leaveFormTo(
    BuildContext formContext,
    GoRouter router,
    String location, {
    Object? extra,
    bool replace = false,
  }) {
    final navigator = Navigator.of(formContext);
    if (!navigator.canPop()) {
      router.go(location, extra: extra);
      return;
    }
    navigator.pop(true); // ferme create_trip_screen, contrat bool intact
    if (replace) {
      router.go(location, extra: extra);
    } else {
      unawaited(router.push(location, extra: extra));
    }
  }

  /// Écran de succès d'un trajet enregistré en brouillon (FLUTTER-FW).
  ///
  /// Même mécanique de pops que l'écran « Trajet publié » : le GoRouter est
  /// capturé AVANT de fermer l'écran de succès puis le formulaire (contrat
  /// `pop(true)` intact pour les appelants).
  Future<void> _showDraftSaved(
    BuildContext context,
    AnnouncementModel announcement,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => DonySuccessScreen(
          key: const Key('trip-draft-saved'),
          mascotteType: DonyMascotteType.succes,
          title: routeContext.l10n.tripDraftSavedTitle,
          subtitle: routeContext.l10n.tripDraftSavedSubtitle,
          ctaLabel: routeContext.l10n.tripDraftSavedViewDraftsCta,
          onCta: () {
            final router = GoRouter.of(routeContext);
            Navigator.of(routeContext).pop();
            _leaveFormTo(context, router, '/announcements/trips?filter=draft');
          },
          analyticsContext: 'trip_draft_saved',
          secondaryLabel: routeContext.l10n.tripDraftSavedViewDraftCta,
          onSecondary: () {
            final router = GoRouter.of(routeContext);
            Navigator.of(routeContext).pop();
            _leaveFormTo(
              context,
              router,
              '/announcements/${announcement.id}/trip',
            );
          },
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    DateTime firstDate = today;
    DateTime lastDate = today.add(const Duration(days: 365));
    if (_isLocked) {
      // Fenêtre de la demande, plancher aujourd'hui : même calcul que la
      // feuille d'offre (LockedTripContext.travelDateWindow).
      final window = widget.lockContext!.travelWindow;
      firstDate = window.first;
      lastDate = window.last;
    }
    final initial =
        _departureDateNotifier.value ??
        (_isLocked
            ? widget.lockContext!.desiredDate ??
                  today.add(const Duration(days: 1))
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
      // Route : une arrivée choisie par « Autre date » garde sa date si elle
      // tient encore dans la fenêtre du mode, sinon elle suit le départ et
      // l'écran le dit.
      final maxDays = arrivalChipsMaxDays(_transportModeNotifier.value);
      final arrival = arrivalOffsetAfterDepartureChange(
        oldDeparture: _departureDateNotifier.value,
        newDeparture: picked,
        offset: _arrivalDayOffsetNotifier.value,
        maxDays: maxDays,
      );
      _departureDateNotifier.value = picked;
      _arrivalDayOffsetNotifier.value = arrival.offset;
      if (arrival.moved && mounted) {
        final l = context.l10n;
        DonySnackbar.show(
          context,
          message: l.tripPublishArrivalMovedWithDeparture(
            DateFormat.MMMEd(l.localeName).format(
              DateTime(picked.year, picked.month, picked.day + arrival.offset),
            ),
            maxDays,
          ),
          type: DonySnackbarType.warning,
        );
      }
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
      // Arrivée plus tôt que le départ le même jour : c'est un vol de nuit,
      // on propose le lendemain (modifiable).
      final dep = _departureTimeNotifier.value;
      if (dep != null &&
          _arrivalDayOffsetNotifier.value == 0 &&
          picked.hour * 60 + picked.minute <= dep.hour * 60 + dep.minute) {
        _arrivalDayOffsetNotifier.value = 1;
      }
    }
  }

  /// Arrivée estimée d'un bateau, au plus tôt ([latest] faux) ou au plus
  /// tard : un jour entre le départ (ou l'arrivée au plus tôt) et départ +
  /// 120 jours. Sans départ saisi, la fenêtre part d'aujourd'hui ; la
  /// cohérence reste vérifiée à chaque changement (`_boatArrivalIssue`).
  Future<void> _selectBoatArrival({required bool latest}) async {
    final cs = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final departure = _departureDateNotifier.value;
    final base = departure == null ? today : DateUtils.dateOnly(departure);
    final last = _boatArrivalLimit(base);
    final notifier = latest ? _boatArrivalMaxNotifier : _boatArrivalMinNotifier;
    var first = latest ? (_boatArrivalMinNotifier.value ?? base) : base;
    if (first.isAfter(last)) first = last;
    var initial = notifier.value ?? first;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      // « Hors de portée. » ne disait pas la règle des 120 jours.
      errorInvalidText: arrivalOutOfRangeText(
        context.l10n,
        first: first,
        last: last,
        maxDays: TransportMode.boat.maxArrivalDays,
      ),
      builder: (ctx, child) => arrivalPickerBuilder(
        ctx,
        child,
        colorScheme: ColorScheme.light(primary: cs.primary),
      ),
    );
    if (picked != null && mounted) notifier.value = DateUtils.dateOnly(picked);
  }

  /// Sélection de la date limite de dépôt : le jour puis l'heure, en un seul
  /// geste (retour testeur FLUTTER-PK : l'heure affichée était déduite sans
  /// jamais être choisie).
  ///
  /// Le calendrier est borné à la date de départ quand elle est déjà saisie.
  /// L'heure proposée : celle déjà choisie, sinon l'heure de départ le jour du
  /// départ, 20:00 un autre jour. Heure annulée : le jour seul est gardé, son
  /// heure suit la règle de repli (cf. [_resolveHandoverDeadline]).
  Future<void> _selectHandoverDeadline() async {
    final cs = Theme.of(context).colorScheme;
    final departure = _departureDateNotifier.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = departure ?? today.add(const Duration(days: 365));
    final current = _handoverDeadlineNotifier.value;
    final picked = await pickDateThenTime(
      context,
      first: today,
      last: last,
      initial: current,
      primary: cs.primary,
      initialTimeFor: (day) {
        if (current != null && _hasTime(current)) {
          return TimeOfDay.fromDateTime(current);
        }
        final departureTime = _departureTimeNotifier.value;
        if (departure != null &&
            departureTime != null &&
            DateUtils.isSameDay(day, departure)) {
          return departureTime;
        }
        return const TimeOfDay(hour: 20, minute: 0);
      },
    );
    if (picked == null || !mounted) return;
    _handoverDeadlineNotifier.value = picked.instant ?? picked.day;
    // Choix manuel : annule le délai en attente d'un modèle appliqué, sinon
    // un prochain changement de date de départ écraserait ce choix.
    _pendingHandoverLeadDays = null;
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
              message: context.l10n.tripPublishOfferSentWithTrip,
              type: DonySnackbarType.success,
            );
          } else if (state is NegotiationLoaded &&
              state.thread.status == NegotiationThreadStatus.awaitingPayment) {
            context.pop(true);
            DonySnackbar.show(
              context,
              message: context.l10n.tripPublishTripLinked,
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
            final blockedBy = PublishingReason.fromErrorCode(state.error.code);
            if (blockedBy != null) {
              // Trajet dédié refusé par la limite mensuelle : écran de
              // blocage, puis le même envoi reprend si rien ne bloque plus.
              unawaited(_onPublishingBlocked(blockedBy));
            } else if (block == PaymentCapabilityBlock.cardCapabilityRequired) {
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
        final pending = _pendingKgPriceEnabled;
        if (pending != null) {
          _pendingKgPriceEnabled = null;
          _kgPriceEnabledNotifier.value = pending;
          return;
        }
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
            // Brouillon (FLUTTER-FW) : « Trajet publié ! … est en ligne » était
            // faux, le trajet n'est visible de personne. Le statut renvoyé par
            // le serveur fait foi, pas l'intention du bouton.
            if (!isEdit && announcement.status == 'DRAFT') {
              unawaited(_showDraftSaved(context, announcement));
              return;
            }
            final stripe = context.read<StripeAccountBloc>().state;
            final needsPayouts =
                !isEdit &&
                stripe is StripeAccountReady &&
                stripe.accountStatus.needsOnboarding &&
                stripe.connectAvailableInCountry;
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (routeContext) {
                    // Le contexte de la route succès (routeContext) reste monté
                    // sous le Navigator racine après les deux pops ci-dessous —
                    // on capture donc le GoRouter AVANT de popper, pour éviter
                    // « Looking up a deactivated widget's ancestor is unsafe »
                    // (même classe de bug que le fix bid-payé, feb86b71).
                    // Chaque action referme l'écran de succès puis le formulaire
                    // (contrat bool intact pour les 3 appelants) avant de
                    // naviguer, même quand le formulaire est seul dans la
                    // pile (voir _leaveFormTo).
                    void leaveTo(
                      String location, {
                      Object? extra,
                      bool replace = false,
                    }) {
                      final router = GoRouter.of(routeContext);
                      Navigator.of(
                        routeContext,
                      ).pop(); // ferme DonySuccessScreen
                      _leaveFormTo(
                        context,
                        router,
                        location,
                        extra: extra,
                        replace: replace,
                      );
                    }

                    void viewTrip() =>
                        leaveTo('/announcements/${announcement.id}/trip');
                    // Le partage de texte seul ne convertit pas : sur Facebook,
                    // c'est le visuel qui arrête le regard, et le lien doit
                    // vivre dans la légende pour rester cliquable. On envoie
                    // donc vers l'affiche, qui fournit l'image, le lien et la
                    // légende en un seul écran.
                    void sharePoster() => leaveTo(
                      '/announcements/${announcement.id}/affiche',
                      extra: announcement,
                    );
                    // Guidage après KYC : les paiements ne sont plus demandés
                    // à l'inscription ; on les propose ici, une fois le premier
                    // trajet publié, si le compte Stripe reste à configurer.
                    void setUpPayouts() => leaveTo('/connect/onboarding/intro');
                    // Médiane de 2,7 jours entre la publication d'un trajet et
                    // la première offre sur un colis : on emmène le voyageur
                    // droit vers les colis compatibles avec ses trajets.
                    void seeParcels() {
                      getIt<PendingSearchNotifier>()
                          .setPendingParcelsForMyTrips();
                      leaveTo('/home', replace: true);
                    }

                    final l = routeContext.l10n;
                    return DonySuccessScreen(
                      mascotteType: DonyMascotteType.succes,
                      title: isEdit
                          ? l.tripPublishSuccessTitleEdit
                          : l.tripPublishSuccessTitleCreate,
                      subtitle: state is AnnouncementTripCreated
                          ? l.tripLegsSuccessSubtitle(
                              state.legs.length,
                              [
                                state.legs.first.departureCity,
                                ...state.legs.map((leg) => leg.arrivalCity),
                              ].join(' → '),
                            )
                          : l.tripPublishSuccessSubtitle(
                              announcement.departureCity,
                              announcement.arrivalCity,
                            ),
                      ctaVariant: DonyButtonVariant.accent,
                      // Création : « Voir les colis pour ce trajet » d'abord,
                      // « Voir mon trajet » en secondaire. Modification : le
                      // trajet existait déjà, l'écran garde « Voir mon trajet »
                      // en bouton principal. Le contexte change (`_v2`) pour ne
                      // pas mélanger, dans PostHog, deux sens du même bouton.
                      ctaLabel: isEdit
                          ? l.tripPublishSuccessCta
                          : l.tripPublishSuccessParcelsCta,
                      onCta: isEdit ? viewTrip : seeParcels,
                      modalMoment: isEdit
                          ? null
                          : VideoModalMoment.action(
                              VideoModalTrigger.tripPublished,
                              corridor: tripMomentCorridor(announcement),
                            ),
                      analyticsContext: isEdit
                          ? 'trip_published'
                          : 'trip_published_v2',
                      // Trajet récurrent : un trajet direct tout juste créé
                      // peut être répété à d'autres dates (yadony-back #525).
                      // Jamais en bateau : le back refuse modèles et
                      // récurrences bateau (422 `boat-template-unsupported`).
                      extra:
                          !isEdit &&
                              state is! AnnouncementTripCreated &&
                              announcement.tripGroupId == null &&
                              announcement.transportMode != TransportMode.boat
                          ? TripSeriesCard(announcement: announcement)
                          : null,
                      secondaryLabel: isEdit ? null : l.tripPublishSuccessCta,
                      onSecondary: isEdit ? null : viewTrip,
                      secondaryIconAsset: null,
                      tertiaryLabel: isEdit
                          ? null
                          : l.tripPublishSuccessShareCta,
                      onTertiary: isEdit ? null : sharePoster,
                      extraActions: needsPayouts
                          ? [
                              DonySuccessAction(
                                label: l.tripPublishSuccessPayoutsCta,
                                onTap: setUpPayouts,
                              ),
                            ]
                          : const [],
                    );
                  },
                ),
              ),
            );
          } else if (state is AnnouncementProLimitReached) {
            context.pop();
            if (context.mounted) {
              final goPro = await showProLimitReachedDialog(
                context,
                title: context.l10n.tripPublishMonthlyLimitTitle,
                message: ErrorPresenter.resolve(
                  state.error,
                  l10n: context.l10n,
                ).message,
              );
              if (goPro && context.mounted) {
                unawaited(context.push('/profile/upgrade-to-pro'));
              }
            }
          } else if (state is AnnouncementDraftLimitReached) {
            context.pop();
            if (context.mounted) {
              final goPro = await showProLimitReachedDialog(
                context,
                title: context.l10n.tripPublishDraftLimitTitle,
                message: ErrorPresenter.resolve(
                  state.error,
                  l10n: context.l10n,
                ).message,
              );
              if (goPro && context.mounted) {
                unawaited(context.push('/profile/upgrade-to-pro'));
              }
            }
          } else if (state is AnnouncementPublishingBlocked) {
            unawaited(_onPublishingBlocked(state.reason));
          } else if (state is AnnouncementTripUnsupported) {
            DonySnackbar.show(
              context,
              message: context.l10n.tripLegsUnsupported,
              type: DonySnackbarType.warning,
            );
          } else if (state is AnnouncementError) {
            // Demande arrivée pendant la modification (FLUTTER-KV) : la devise
            // se fige, l'écran revient à celle du trajet et l'explique.
            if (_isEdit && state.error.code == 'announcement/currency-locked') {
              widget.currencyEditableNotifier?.value = false;
              widget.currencyNotifier.value =
                  SupportedCurrency.fromCodeOrDefault(
                    widget.announcement!.currency,
                  );
            }
            unawaited(ErrorPresenter.show(context, state.error));
          }
        },
        builder: (context, state) =>
            BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
              listenWhen: (prev, curr) => prev.availableKg != curr.availableKg,
              listener: (context, formState) {
                final kg = formState.availableKg ?? 0.0;
                if (kg == _availableKgNotifier.value) return;
                _applyingKgFromBloc = true;
                _availableKgNotifier.value = kg;
                _applyingKgFromBloc = false;
              },
              child: BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
                listenWhen: (prev, curr) =>
                    prev.isCapacityStepValid != curr.isCapacityStepValid,
                listener: (_, _) => _updateCanContinueStep1(),
                // Bateau : unité de vente choisie à l'étape Capacité, recopiée
                // dans le formulaire (règle du prix) ; le volume compte comme
                // une saisie.
                child:
                    BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
                      listenWhen: (prev, curr) =>
                          prev.boatPriceUnit != curr.boatPriceUnit ||
                          prev.volumeCapacityM3 != curr.volumeCapacityM3,
                      listener: (_, formState) {
                        final unit = formState.boatPriceUnit;
                        if (unit != null) _boatPriceUnitNotifier.value = unit;
                        _markDirty();
                      },
                      child: formChild,
                    ),
              ),
            ),
      ),
    );
  }

  /// Applique un modèle de trajet enregistré : tout le formulaire sauf la date.
  ///
  /// Un champ nul dans le modèle (modèle antérieur au formulaire complet)
  /// vaut le défaut du formulaire vierge. La devise est posée en premier :
  /// les chips de prix en dépendent. Les moyens de paiement impossibles ici
  /// (mobile money sans compte actif ou hors zone CFA) sont ignorés, comme la
  /// soumission les retirerait ; la carte reste gérée par la garde existante
  /// à la soumission (Stripe non configuré), pas dupliquée ici.
  void _applyTemplate(TripTemplate t) {
    final currency = SupportedCurrency.fromCode(t.currency);
    if (currency != null) _setCurrencyFromSnapshot(currency);

    // Codes pays AVANT les villes : le listener des villes recopie le code
    // courant dans le form bloc, lu à la soumission. Dans l'ordre inverse,
    // tout trajet publié depuis un modèle partait sans pays (FLUTTER-EH).
    _departureCountryCodeNotifier.value = t.departureCountryCode;
    _arrivalCountryCodeNotifier.value = t.arrivalCountryCode;
    _departureCityNotifier.value = t.departureCity;
    _arrivalCityNotifier.value = t.arrivalCity;
    // Ville identique à celle déjà saisie : le notifier ne notifie pas, le
    // bloc garderait l'ancien code. Resynchronisation explicite.
    _syncCityToFormBloc();
    // Le mode n'est pas repris du modèle (création seulement) : choisi à
    // l'étape Mode, il prime ; sans étape Mode, c'est l'avion. Un modèle
    // BOAT ou CAR ne change donc jamais en silence le mode du trajet. Un
    // trajet dédié ne perd jamais le mode de sa demande. Posé AVANT le
    // décalage d'arrivée : sinon `_clampArrivalOffsetToMode` remettrait à 0
    // un J+3 d'avion venu d'un modèle avion.
    if (!_hasModeStep && !_isLocked) {
      _transportModeNotifier.value = TransportMode.plane;
    }
    // Mode encore à choisir : celui du modèle est retenu pour le premier
    // choix (`_clampArrivalOffsetToMode`).
    _templateMode = _transportModeNotifier.value == null
        ? transportModeFromWire(t.transportMode)
        : null;
    _departureTimeNotifier.value = _timeOfDay(t.departureTime);
    _arrivalTimeNotifier.value = _timeOfDay(t.arrivalTime);
    // Vol de nuit mémorisé dans le modèle (FLUTTER-4E), arrivée à J+N d'un
    // modèle route ; borné au mode choisi.
    _arrivalDayOffsetNotifier.value = _templateArrivalOffset(t);
    // Valeur optimiste immédiate ; `CapacityUnitChanged` ci-dessous réécrit
    // `availableKg` à `unit.maxKg` (valise 23/32 kg) côté bloc — l'event
    // `AvailableKgChanged` émis juste après restaure la valeur du modèle via
    // le `BlocListener` existant (constat #2 : sans lui, un modèle « valise
    // 32 kg, 64 kg » s'appliquait à 32 kg).
    _availableKgNotifier.value = t.availableKg.toDouble();
    _pickupAddressNotifier.value = t.pickupAddress;
    _deliveryAddressNotifier.value = t.deliveryAddress;

    _kgPriceEnabledNotifier.value = !t.usesPriceGrid || t.pricePerKg != null;
    final price = t.pricePerKg;
    if (price == null) {
      _priceOptionNotifier.value = -1;
    } else {
      final presetIdx = _presets.indexOf(price);
      if (presetIdx != -1) {
        _priceOptionNotifier.value = presetIdx;
      } else {
        _priceOptionNotifier.value = _presets.length; // "Autre prix"
        _customPriceNotifier.value = price;
        _customPriceCtrl.text = formatKgPrice(price);
      }
    }

    _selectedContentNotifier.value = t.acceptedCategories
        .where(_catalogLabelsNotifier.value.contains)
        .toSet();
    _customAcceptedNotifier.value = t.acceptedCategories
        .where((c) => !_catalogLabelsNotifier.value.contains(c))
        .toSet();
    _refusedTypesNotifier.value = t.refusedTypes.toSet();
    _descriptionCtrl.text = t.description ?? '';
    _negotiableNotifier.value = t.negotiable;

    final mobileMoneyPossible =
        _currency.isMobileMoneyEligible &&
        mobileMoneyAccountActiveFrom(
          context.read<MobileMoneyAccountBloc>().state,
        );
    _cashEnabledNotifier.value = t.acceptedPaymentMethods.contains('CASH');
    _cardEnabledNotifier.value = t.acceptedPaymentMethods.contains('STRIPE');
    _mobileMoneyEnabledNotifier.value =
        mobileMoneyPossible &&
        t.acceptedPaymentMethods.contains('MOBILE_MONEY');

    _pendingHandoverLeadDays = t.handoverLeadDays;
    if (_pendingHandoverLeadDays == null) {
      // Champ nul = défaut du formulaire vierge : sans ce reset, la date
      // limite d'un modèle précédemment appliqué restait affichée alors que
      // celui-ci n'en porte aucune.
      _handoverDeadlineNotifier.value = null;
    } else {
      _applyPendingHandoverLead();
    }

    final unit = switch (t.capacityUnit) {
      'KG_FREE' => CapacityUnit.kgFree,
      'SUITCASE_32KG' => CapacityUnit.suitcase32kg,
      'KG_EXACT' => CapacityUnit.custom,
      _ => CapacityUnit.suitcase23kg,
    };
    final formBloc = context.read<AnnouncementFormBloc>();
    formBloc.add(CapacityUnitChanged(unit));
    formBloc.add(AvailableKgChanged(t.availableKg.toDouble()));
    formBloc.add(
      AnnouncementPricingModeSetRequested(
        t.usesPriceGrid ? PricingMode.mixed : PricingMode.kg,
      ),
    );
    // Taille et poids max par colis du modèle, si le mode choisi (ou encore à
    // choisir) en porte : choisir ensuite l'avion les efface dans le bloc
    // (`TransportModeChanged`), jamais envoyés en silence.
    final mode = _transportModeNotifier.value;
    if (mode == null || mode.hasItemSize) {
      formBloc
        ..add(MaxItemSizeChanged(t.maxItemSize))
        ..add(MaxParcelWeightChanged(t.maxParcelWeightKg));
    }

    DonySnackbar.show(
      context,
      message: context.l10n.tripPublishTemplateAppliedMessage(t.label),
      type: DonySnackbarType.success,
    );
  }

  /// Délai de remise du dernier modèle appliqué, en jours avant le départ.
  /// Réappliqué à chaque changement de date tant que l'utilisateur n'a pas
  /// choisi lui-même un jour limite (le choix manuel l'annule, cf.
  /// [_selectHandoverDeadline]).
  int? _pendingHandoverLeadDays;

  void _applyPendingHandoverLead() {
    final lead = _pendingHandoverLeadDays;
    final date = _departureDateNotifier.value;
    if (lead == null || date == null) return;
    _handoverDeadlineNotifier.value = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: lead));
  }

  /// Saisie complète du formulaire, au format du brouillon local.
  TripFormDraft _draftSnapshot() {
    final formState = context.read<AnnouncementFormBloc>().state;
    final departureTime = _departureTimeNotifier.value;
    final arrivalTime = _arrivalTimeNotifier.value;
    final mode = _transportModeNotifier.value;
    return TripFormDraft(
      stepId: widget.currentStepNotifier?.value ?? widget.steps.first,
      currency: _currency.code,
      departureCity: _departureCityNotifier.value,
      departureCountryCode: _departureCountryCodeNotifier.value,
      arrivalCity: _arrivalCityNotifier.value,
      arrivalCountryCode: _arrivalCountryCodeNotifier.value,
      departureDate: _departureDateNotifier.value,
      departureTime: departureTime == null ? null : _formatTime(departureTime),
      arrivalTime: arrivalTime == null ? null : _formatTime(arrivalTime),
      arrivalDayOffset: _arrivalDayOffsetNotifier.value,
      handoverDeadline: _handoverDeadlineNotifier.value,
      handoverLeadDays: _pendingHandoverLeadDays,
      transportMode: mode == null ? null : transportModeToWire(mode),
      stops: _stopsNotifier.value,
      pickupAddress: _pickupAddress,
      deliveryAddress: _deliveryAddress,
      availableKg: _availableKgNotifier.value,
      capacityUnit: formState.capacityUnit.toWire(),
      pricingMode: formState.pricingMode == PricingMode.mixed ? 'MIXED' : 'KG',
      kgPriceEnabled: _kgPriceEnabledNotifier.value,
      priceOption: _priceOptionNotifier.value,
      customPrice: _customPriceNotifier.value,
      customPriceText: _customPriceCtrl.text,
      acceptedContent: _selectedContentNotifier.value.toList(),
      customAccepted: _customAcceptedNotifier.value.toList(),
      refusedTypes: _refusedTypesNotifier.value.toList(),
      description: _descriptionCtrl.text,
      cashEnabled: _cashEnabledNotifier.value,
      cardEnabled: _cardEnabledNotifier.value,
      mobileMoneyEnabled: _mobileMoneyEnabledNotifier.value,
      negotiable: _negotiableNotifier.value,
      legs: context.read<TripLegsCubit>().state.legs,
      maxItemSize: formState.maxItemSize,
      maxParcelWeightKg: formState.maxParcelWeightKg,
      arrivalDate: _boatArrivalMinNotifier.value,
      arrivalDateMax: _boatArrivalMaxNotifier.value,
      volumeM3: formState.volumeCapacityM3,
      pricePerM3: parsePriceInput(_pricePerM3Ctrl.text),
      boatPriceUnit: _boatPriceUnitNotifier.value,
    );
  }

  /// Recharge un brouillon local, date comprise (à la différence d'un
  /// modèle). Même ordre que [_applyTemplate] : la devise d'abord, dont
  /// dépendent les puces de prix, et les codes pays avant les villes.
  void _restoreDraft(TripFormDraft d) {
    _restoredFromDraft = true;
    final currency = SupportedCurrency.fromCode(d.currency);
    if (currency != null) _setCurrencyFromSnapshot(currency);

    _departureCountryCodeNotifier.value = d.departureCountryCode;
    _arrivalCountryCodeNotifier.value = d.arrivalCountryCode;
    _departureCityNotifier.value = d.departureCity;
    _arrivalCityNotifier.value = d.arrivalCity;
    _syncCityToFormBloc();
    _departureDateNotifier.value = d.departureDate;
    _departureTimeNotifier.value = _timeOfDay(d.departureTime);
    _arrivalTimeNotifier.value = _timeOfDay(d.arrivalTime);
    final draftMode = _creationModeFrom(d.transportMode);
    // Avant le mode : son changement envoie l'unité au bloc.
    _boatPriceUnitNotifier.value = d.boatPriceUnit ?? BoatPriceUnit.m3;
    // Le brouillon garde jusqu'à 120 jours (bateau) : borné ici au mode
    // retenu, un J+10 de route devient J+3 en avion.
    // Mode d'abord : son changement ramène le décalage à 0, la restauration
    // pose ensuite le décalage du brouillon (borné au mode).
    _transportModeNotifier.value = draftMode;
    // Sans heure d'arrivée, le jour d'arrivée ne vaut qu'en route (C28).
    _arrivalDayOffsetNotifier.value = effectiveArrivalOffset(
      mode: draftMode,
      hasArrivalTime: d.arrivalTime != null,
      offset: d.arrivalDayOffset,
    ).clamp(0, transportModeOrPlane(draftMode).maxArrivalDays);
    _stopsNotifier.value = d.stops;
    _boatArrivalMinNotifier.value = d.arrivalDate;
    _boatArrivalMaxNotifier.value = d.arrivalDateMax;
    final pricePerM3 = d.pricePerM3;
    _pricePerM3Ctrl.text = pricePerM3 == null
        ? ''
        : _priceInputText(pricePerM3);
    // Après la date : son listener réapplique un délai de modèle en attente.
    _pendingHandoverLeadDays = d.handoverLeadDays;
    _handoverDeadlineNotifier.value = d.handoverDeadline;

    final kg = d.availableKg;
    if (kg != null) _availableKgNotifier.value = kg;
    _pickupAddressNotifier.value = d.pickupAddress;
    _deliveryAddressNotifier.value = d.deliveryAddress;

    _kgPriceEnabledNotifier.value = d.kgPriceEnabled;
    _priceOptionNotifier.value = d.priceOption.clamp(-1, _presets.length);
    final customPrice = d.customPrice;
    if (customPrice != null) _customPriceNotifier.value = customPrice;
    _customPriceCtrl.text = d.customPriceText;

    _selectedContentNotifier.value = d.acceptedContent.toSet();
    _customAcceptedNotifier.value = d.customAccepted.toSet();
    _refusedTypesNotifier.value = d.refusedTypes.toSet();
    _descriptionCtrl.text = d.description;
    _negotiableNotifier.value = d.negotiable;

    final mobileMoneyPossible =
        _currency.isMobileMoneyEligible &&
        mobileMoneyAccountActiveFrom(
          context.read<MobileMoneyAccountBloc>().state,
        );
    _cashEnabledNotifier.value = d.cashEnabled;
    _cardEnabledNotifier.value = d.cardEnabled;
    _mobileMoneyEnabledNotifier.value =
        mobileMoneyPossible && d.mobileMoneyEnabled;

    final formBloc = context.read<AnnouncementFormBloc>();
    final unit = switch (d.capacityUnit) {
      'KG_FREE' => CapacityUnit.kgFree,
      'SUITCASE_32KG' => CapacityUnit.suitcase32kg,
      'KG_EXACT' => CapacityUnit.custom,
      _ => CapacityUnit.suitcase23kg,
    };
    formBloc.add(CapacityUnitChanged(unit));
    // Comme pour un modèle : l'unité réécrit le kg à son maximum, le kg
    // saisi passe ensuite.
    if (kg != null) formBloc.add(AvailableKgChanged(kg));
    // Après le mode : vers un mode sans taille ni poids max, le bloc les
    // aurait effacés.
    if (transportModeOrPlane(draftMode).hasItemSize) {
      formBloc.add(MaxItemSizeChanged(d.maxItemSize));
    }
    if (transportModeOrPlane(draftMode).hasMaxParcelWeight) {
      formBloc.add(MaxParcelWeightChanged(d.maxParcelWeightKg));
    }
    // Unité de vente du brouillon : aussi quand le mode n'a pas changé (déjà
    // bateau), sans quoi le bloc garderait l'unité d'avant.
    formBloc
      ..add(BoatPriceUnitChanged(_boatPriceUnitNotifier.value!))
      ..add(VolumeCapacityChanged(d.volumeM3));
    // Pas de grille en bateau.
    final pricingMode =
        d.pricingMode == 'MIXED' && draftMode != TransportMode.boat
        ? PricingMode.mixed
        : PricingMode.kg;
    _pendingKgPriceEnabled = formBloc.state.pricingMode != pricingMode
        ? d.kgPriceEnabled
        : null;
    formBloc.add(AnnouncementPricingModeSetRequested(pricingMode));

    context.read<TripLegsCubit>().restore(d.legs);
    _updateCanContinueStep1();
    _markDirty();
  }

  /// Mode d'un brouillon local (création seulement) : gardé s'il est
  /// proposable à la publication (BUS compte pour la Route) ; absent ou non
  /// proposable (BOAT avant le lot 3, mode éteint), ramené au défaut de la
  /// création : à choisir à l'étape Mode, ou l'avion sans choix (C1, C12).
  TransportMode? _creationModeFrom(String? wire) {
    final mode = transportModeFromWire(wire);
    // Bateau d'un brouillon (ou de l'IA) pour un voyageur non vérifié : sa
    // carte est grisée, le mode reste à choisir.
    final proposable =
        mode != null &&
        widget.tripModes.any((m) => m.displayGroup == mode.displayGroup) &&
        (mode != TransportMode.boat || _canPublishBoat);
    if (proposable) return mode;
    return _hasModeStep ? null : TransportMode.plane;
  }

  static TimeOfDay? _timeOfDay(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // ── Mode ───────────────────────────────────────────────────────────────────
  List<Widget> _buildModeStep() => [
    BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final user = auth.currentUser;
        return ModeStep(
          modes: widget.tripModes,
          notifier: _transportModeNotifier,
          // Bateau réservé aux transporteurs vérifiés (C15) : carte grisée et
          // lien vers la demande de badge GP Pro.
          boatLocked: user == null || !canPublishBoat(user),
          onRequestBoatBadge: () {
            unawaited(
              getIt<AnalyticsService>().logEvent(
                AnalyticsEvents.tripBoatBadgeRequestTapped,
              ),
            );
            unawaited(context.push('/profile/gp-pro'));
          },
        );
      },
    ),
  ];

  /// Modes de la ligne « Mode de transport » (modification) : sans le bateau
  /// pour un voyageur non vérifié, sauf s'il est le mode du trajet (la ligne
  /// montre toujours le mode réel).
  List<TransportMode> get _modeRowModes => [
    for (final mode in widget.tripModes)
      if (mode != TransportMode.boat || _canPublishBoat) mode,
  ];

  // ── Trajet ─────────────────────────────────────────────────────────────────
  List<Widget> _buildStep0(BuildContext context) {
    return [
      if (_isLocked) ...[
        _LockedBanner(lockContext: widget.lockContext!),
        const SizedBox(height: DonySpacing.lg),
      ],
      if (_lockedBoatBlocked) ...[
        _LockedBoatBlockedNote(
          onRequestBadge: () {
            unawaited(
              getIt<AnalyticsService>().logEvent(
                AnalyticsEvents.tripBoatBadgeRequestTapped,
              ),
            );
            unawaited(context.push('/profile/gp-pro'));
          },
        ),
        const SizedBox(height: DonySpacing.lg),
      ],
      ListenableBuilder(
        listenable: Listenable.merge([
          _step0ErrorsNotifier,
          _boatArrivalMinNotifier,
          _boatArrivalMaxNotifier,
          _departureDateNotifier,
          _transportModeNotifier,
        ]),
        builder: (context, _) => TrajetStep(
          departureCityNotifier: _departureCityNotifier,
          arrivalCityNotifier: _arrivalCityNotifier,
          departureCountryCodeNotifier: _departureCountryCodeNotifier,
          arrivalCountryCodeNotifier: _arrivalCountryCodeNotifier,
          departureDateNotifier: _departureDateNotifier,
          departureTimeNotifier: _departureTimeNotifier,
          arrivalTimeNotifier: _arrivalTimeNotifier,
          arrivalDayOffsetNotifier: _arrivalDayOffsetNotifier,
          stopsNotifier: _stopsNotifier,
          transportModeNotifier: _transportModeNotifier,
          // Pas d'étape Mode en modification ni en trajet dédié à mode connu :
          // le mode se lit (et se change en modification) en tête de l'étape.
          // Un trajet dédié « peu importe » a l'étape Mode, donc pas de ligne.
          // Avion seul proposé et trajet avion : rien à choisir, pas de ligne.
          transportModeRowModes: _showModeRow ? _modeRowModes : null,
          // Trajet dédié : le mode ne change pas. Un trajet bateau modifié
          // peut changer de mode comme un autre : le back seul refuse (409
          // `transport-mode-locked`) quand un colis, une offre ou un fil
          // vivant existe (recette du 13/11 : seul « Bateau » proposé sur un
          // trajet sans colis).
          transportModeRowReadOnly: _isLocked,
          onSelectDepartureTime: _selectDepartureTime,
          onSelectArrivalTime: _selectArrivalTime,
          onSelectDate: _selectDate,
          departureCityError: _msg(
            context.l10n,
            _step0ErrorsNotifier.value,
            _Step0Field.departureCity,
          ),
          arrivalCityError: _msg(
            context.l10n,
            _step0ErrorsNotifier.value,
            _Step0Field.arrivalCity,
          ),
          departureDateError: _msg(
            context.l10n,
            _step0ErrorsNotifier.value,
            _Step0Field.departureDate,
          ),
          departureTimeError: _msg(
            context.l10n,
            _step0ErrorsNotifier.value,
            _Step0Field.departureTime,
          ),
          // Trajet dédié : la fourchette d'arrivée n'existe que pour le bateau.
          boatArrivalMinNotifier: _isLocked && !_isBoat
              ? null
              : _boatArrivalMinNotifier,
          boatArrivalMaxNotifier: _isLocked && !_isBoat
              ? null
              : _boatArrivalMaxNotifier,
          onSelectBoatArrivalMin: () => _selectBoatArrival(latest: false),
          onSelectBoatArrivalMax: () => _selectBoatArrival(latest: true),
          boatArrivalError: _boatArrivalMessage(context.l10n),
          // Corridor verrouillé en modification (Q1) ET en trajet dédié (lockContext).
          // Date verrouillée seulement en modification ; le dédié la garde éditable
          // dans la fenêtre de tolérance.
          lockCorridor: widget.lockCorridorAndDate || _isLocked,
          lockDate: widget.lockCorridorAndDate,
        ),
      ),
      CaSectionLabel(
        label: context.l10n.tripPublishDropoffSectionLabel,
        iconAsset: 'package',
      ),
      const SizedBox(height: DonySpacing.xs),
      CaSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Le jour seul ne suffisait pas : le jour du départ, la limite
            // est l'heure de départ, pas la fin de journée, et rien ne le
            // disait (Sentry FLUTTER-MY). Le voyageur choisit désormais le jour
            // puis l'heure (FLUTTER-PK) ; l'heure affichée est celle que
            // [_resolveHandoverDeadline] enverra : l'heure choisie, ou à défaut
            // la règle de repli, recalculée si le départ change.
            AnimatedBuilder(
              animation: Listenable.merge([
                _handoverDeadlineNotifier,
                _departureDateNotifier,
                _departureTimeNotifier,
              ]),
              builder: (context, _) => ListTile(
                key: const Key('sheet-handover-deadline-row'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base,
                ),
                leading: DonyIcon(
                  'calendar',
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(context.l10n.tripPublishHandoverDeadlineLabel),
                subtitle: Text(
                  context.l10n.tripPublishHandoverDeadlineSubtitle,
                ),
                trailing: Text(
                  _handoverDeadlineDisplay(context.l10n) ??
                      context.l10n.tripPublishHandoverDeadlineChoose,
                  key: const Key('sheet-handover-deadline-value'),
                  textAlign: TextAlign.end,
                ),
                onTap: _selectHandoverDeadline,
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([
                _handoverDeadlineNotifier,
                _departureDateNotifier,
                _departureTimeNotifier,
                _step0ErrorsNotifier,
              ]),
              builder: (context, _) {
                // Deux erreurs distinctes sur la même ligne : « date limite
                // incohérente » (postérieure au départ) et « date limite
                // absente » (rien de choisi). La seconde n'apparaît qu'après
                // une première interaction avec l'étape.
                final err = _isHandoverDeadlineInvalid()
                    ? context.l10n.tripPublishHandoverDeadlineInvalid
                    : (_step0ErrorsNotifier.value.contains(
                            _Step0Field.handoverDeadline,
                          )
                          ? _step0FieldMessage(
                              context.l10n,
                              _Step0Field.handoverDeadline,
                            )
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

  // ── Capacité (lieux de remise et kilos) ────────────────────────────────────
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
              ? _step1FieldMessage(context.l10n, _Step1Field.pickupAddress)
              : null,
          deliveryAddressError: missing.contains(_Step1Field.deliveryAddress)
              ? _step1FieldMessage(context.l10n, _Step1Field.deliveryAddress)
              : null,
          // Trajet dédié : capacité fixée par la demande → affichage verrouillé.
          // Demande par bateau : le volume du colis, pas des kilos.
          lockedCapacityKg: _isLocked ? widget.lockContext!.weightKg : null,
          lockedVolumeM3: _isLocked && _isBoat
              ? widget.lockContext!.volumeM3
              : null,
          lockedTransportMode: _isLocked
              ? widget.lockContext!.transportMode
              : null,
          transportMode: _transportModeNotifier.value,
        ),
      ),
    ];
  }

  // ── Prix ───────────────────────────────────────────────────────────────────
  List<Widget> _buildPrixStep(BuildContext context) {
    return [
      // Devise du trajet, juste avant les prix qu'elle exprime (FLUTTER-RA).
      // Création : sélecteur libre ; modification : selon `currencyEditable` ;
      // trajet dédié : devise de la demande, rien à choisir.
      if (!_isEdit && !_isLocked) ...[
        CurrencySelectionBanner(currencyNotifier: widget.currencyNotifier),
        const SizedBox(height: DonySpacing.base),
      ] else if (_isEdit &&
          !_isLocked &&
          widget.currencyEditableNotifier != null)
        _EditCurrencySection(
          editableNotifier: widget.currencyEditableNotifier!,
          currencyNotifier: widget.currencyNotifier,
        ),
      BlocBuilder<MobileMoneyAccountBloc, MobileMoneyAccountState>(
        builder: (context, mobileMoneyState) {
          final mobileMoneyAccountActive = mobileMoneyAccountActiveFrom(
            mobileMoneyState,
          );
          return ListenableBuilder(
            listenable: Listenable.merge([
              widget.currencyNotifier,
              ?widget.currencyEditableNotifier,
            ]),
            builder: (context, _) => PrixStep(
              currency: widget.currencyNotifier.value,
              gridCurrency: ActiveCurrency.current,
              priceOptionNotifier: _priceOptionNotifier,
              customPriceNotifier: _customPriceNotifier,
              availableKgNotifier: _availableKgNotifier,
              cashEnabledNotifier: _cashEnabledNotifier,
              cardEnabledNotifier: _cardEnabledNotifier,
              kgPriceEnabledNotifier: _kgPriceEnabledNotifier,
              mobileMoneyEnabledNotifier: _mobileMoneyEnabledNotifier,
              currencyNotifier: widget.currencyNotifier,
              mobileMoneyAccountActive: mobileMoneyAccountActive,
              mobileMoneyCurrencies: mobileMoneyAccountCurrenciesFrom(
                mobileMoneyState,
              ),
              // Changer la devise du premier trajet ne touche pas celle des
              // étapes ajoutées (FLUTTER-HP) : la confirmation les cite.
              legCurrencies: _isEdit || _isLocked ? null : _extraLegCurrencies,
              onMobileMoneySetupReturned: () => context
                  .read<MobileMoneyAccountBloc>()
                  .add(const MobileMoneyAccountsRequested()),
              negotiableNotifier: _negotiableNotifier,
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
              pricePerM3Ctrl: _pricePerM3Ctrl,
              // Hors bateau, rien à lire (aucun AuthBloc requis).
              showBoatDepositNotice: _isBoat && _canPublishBoat,
              // En modification, la devise ne change que si le serveur le
              // permet (`currencyEditable`, FLUTTER-KV) : le PUT l'envoie
              // alors. Sinon elle reste figée, sans quoi l'écran validait le
              // prix dans une devise que le PUT n'envoyait pas (FLUTTER-JS).
              currencyLocked:
                  _isLocked || (_isEdit && !_isEditCurrencyEditable),
            ),
          );
        },
      ),
    ];
  }

  // ── Conditions ─────────────────────────────────────────────────────────────
  List<Widget> _buildConditionsStep(BuildContext context) {
    final isCreation = !_isEdit && !_isLocked;
    return [
      // « Passer » : rien n'est obligatoire ici, le voyageur va droit à
      // l'aperçu, comme avec « Aperçu » (création seulement, choix C6).
      if (isCreation && widget.canSubmitNotifier != null)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.canSubmitNotifier!,
            builder: (context, canSubmit, _) => TextButton(
              key: const Key('trip-conditions-skip'),
              onPressed: canSubmit && widget.onPreviewRequested != null
                  ? () => widget.onPreviewRequested!(context)
                  : null,
              child: Text(
                context.l10n.tripPublishConditionsSkip,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
      ConditionsStep(
        selectedContentNotifier: _selectedContentNotifier,
        customAcceptedNotifier: _customAcceptedNotifier,
        refusedTypesNotifier: _refusedTypesNotifier,
        catalogLabelsNotifier: _catalogLabelsNotifier,
        descriptionCtrl: _descriptionCtrl,
        customAcceptedCtrl: _customAcceptedCtrl,
        refusedCtrl: _refusedCtrl,
        isRoad: _transportModeNotifier.value?.isRoad ?? false,
      ),
      // Voyage à plusieurs étapes (FLUTTER-4D), sous les conditions (C5) :
      // création seulement. Une modification touche une seule étape, un
      // trajet dédié reste unique, un bateau n'a ni escales ni étapes.
      if (isCreation && !_isBoat)
        ListenableBuilder(
          listenable: Listenable.merge([
            _arrivalCityNotifier,
            _arrivalCountryCodeNotifier,
            _departureDateNotifier,
            _arrivalTimeNotifier,
            _arrivalDayOffsetNotifier,
            _deliveryAddressNotifier,
            _kgPriceEnabledNotifier,
            _transportModeNotifier,
            _stopsNotifier,
            widget.currencyNotifier,
          ]),
          builder: (context, _) => TripLegsSection(
            origin: _firstLegOrigin(),
            showPrice: _kgPriceEnabledNotifier.value,
            tripCurrency: _currency,
            paymentRails: _legPaymentRails,
            defaultKg: _availableKgNotifier.value,
            defaultPrice: context.read<AnnouncementFormBloc>().state.pricePerKg,
            // Escales par étape (FLUTTER-GE), préremplies avec celles du
            // premier trajet.
            showStops: supportsStops(_transportModeNotifier.value),
            defaultStops: _stopsNotifier.value,
            isRoad: _transportModeNotifier.value?.isRoad ?? false,
          ),
        ),
    ];
  }

  /// Décalage d'arrivée à envoyer : en route il compte même sans heure
  /// d'arrivée (C28), ailleurs seulement avec une heure (`effectiveArrivalOffset`).
  int _effectiveArrivalOffset() => effectiveArrivalOffset(
    mode: _transportModeNotifier.value,
    hasArrivalTime: _arrivalTimeNotifier.value != null,
    offset: _arrivalDayOffsetNotifier.value,
  );

  /// Changement de mode : un décalage au-delà de ce que les puces du nouveau
  /// mode proposent (J+10 ou J+3 de route repassé en avion, puces 0 à 2) est
  /// ramené au jour même, jamais envoyé en silence (Review Focus 4 et 5).
  /// L'ouverture en modification garde la valeur du serveur : seul un
  /// changement de mode passe ici.
  ///
  /// Exception : le premier mode choisi après un modèle du MÊME mode garde le
  /// décalage du modèle jusqu'au maximum du mode (vol avion à J+3 enregistré
  /// dans le modèle) : ce n'est pas un changement de mode.
  void _clampArrivalOffsetToMode() {
    final mode = _transportModeNotifier.value;
    if (mode == null) return;
    final templateMode = _templateMode;
    _templateMode = null;
    if (_arrivalDayOffsetNotifier.value > _offsetLimit(mode, templateMode)) {
      _arrivalDayOffsetNotifier.value = 0;
    }
  }

  /// Mode du dernier modèle appliqué, tant que le voyageur n'a pas choisi
  /// son mode (étape Mode après le modèle). Consommé au premier choix.
  TransportMode? _templateMode;

  /// Plus grand décalage gardé pour [mode] : le maximum du mode quand il est
  /// celui du modèle, sinon ce que ses puces proposent (route J+3 repassé en
  /// avion : 0, Review Focus 5).
  static int _offsetLimit(TransportMode mode, TransportMode? templateMode) =>
      mode == templateMode ? mode.maxArrivalDays : arrivalChipsMaxDays(mode);

  /// Décalage d'arrivée repris d'un modèle. Mode déjà connu (avion seul,
  /// trajet dédié) : le mode choisi prime, un décalage hors de ses bornes
  /// revient au jour même. Mode encore inconnu (étape Mode après le modèle) :
  /// gardé tel quel, `_clampArrivalOffsetToMode` le borne au choix du mode.
  int _templateArrivalOffset(TripTemplate t) {
    final mode = _transportModeNotifier.value;
    if (mode == null) return t.arrivalDayOffset;
    final offset = effectiveArrivalOffset(
      mode: mode,
      hasArrivalTime: t.arrivalTime != null,
      offset: t.arrivalDayOffset,
    );
    final templateMode = transportModeFromWire(t.transportMode);
    return offset > _offsetLimit(mode, templateMode) ? 0 : offset;
  }

  /// Arrivée du trajet saisi, d'où part la première étape ajoutée
  /// (FLUTTER-4D). `null` tant que la ville ou la date manque.
  TripLegOrigin? _firstLegOrigin() {
    final city = _arrivalCityNotifier.value;
    final date = _departureDateNotifier.value;
    if (city == null || city.isEmpty || date == null) return null;
    final offset = _effectiveArrivalOffset();
    return TripLegOrigin(
      city: city,
      countryCode: _arrivalCountryCodeNotifier.value,
      arrivalDay: DateUtils.dateOnly(date).add(Duration(days: offset)),
      address: _deliveryAddress,
    );
  }

  Widget _buildForm(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Formulaire à étapes. Offstage garde toutes les étapes dans l'arbre en
    // permanence :
    // - les AddressPickerField (Capacité) ne perdent pas leur état quand on
    //   navigue vers une autre étape
    // - form.validate() et form.save() couvrent tous les champs quelle que
    //   soit l'étape visible
    // - contrairement à IndexedStack, Offstage n'impose pas la hauteur du
    //   plus grand enfant : l'écran se dimensionne au contenu de l'étape active
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.currentStepNotifier,
        _pickupAddressNotifier,
        _deliveryAddressNotifier,
        // Libellés et sections propres au mode (bateau : entrepôt, étapes).
        _transportModeNotifier,
      ]),
      builder: (context, _) {
        final current = widget.currentStepNotifier!.value;
        List<Widget> contentOf(TripFormStep step) => switch (step) {
          TripFormStep.mode => _buildModeStep(),
          TripFormStep.trajet => _buildStep0(context),
          TripFormStep.capacite => _buildStep1(context, tt, cs),
          TripFormStep.prix => _buildPrixStep(context),
          TripFormStep.conditions => _buildConditionsStep(context),
        };
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CaStepperHeader(steps: widget.steps, current: current),
              const SizedBox(height: DonySpacing.lg),
              for (final step in widget.steps)
                Offstage(
                  key: ValueKey('trip-form-step-${step.wire}'),
                  offstage: step != current,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: contentOf(step),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Champs obligatoires par étape ───────────────────────────────────────────

/// Champs obligatoires de l'étape 0, tels que `_submit()` les exige.
///
/// Toute entrée ajoutée ici bloque « Continuer » ET affiche son message sous
/// le champ concerné : impossible d'ajouter l'un sans l'autre.
enum _Step0Field {
  departureCity,
  arrivalCity,
  departureDate,
  departureTime,
  transportMode,
  handoverDeadline,

  /// Bateau : arrivée estimée au plus tôt et au plus tard.
  boatArrival,
}

/// Incohérence de l'arrivée estimée d'un bateau (`_boatArrivalIssue`).
enum _BoatArrivalIssue { beforeDeparture, latestBeforeEarliest, tooFar }

/// Message affiché sous le champ [f]. Repris mot pour mot des gardes de
/// `_submit()` pour que l'utilisateur lise la même chose aux deux endroits.
String _step0FieldMessage(AppLocalizations l10n, _Step0Field f) {
  switch (f) {
    case _Step0Field.departureCity:
      return l10n.tripPublishFieldDepartureCityRequired;
    case _Step0Field.arrivalCity:
      return l10n.tripPublishFieldArrivalCityRequired;
    case _Step0Field.departureDate:
      return l10n.tripPublishFieldDepartureDateRequired;
    case _Step0Field.departureTime:
      return l10n.tripPublishFieldDepartureTimeRequired;
    case _Step0Field.transportMode:
      return l10n.tripPublishFieldTransportModeRequired;
    case _Step0Field.handoverDeadline:
      return l10n.tripPublishFieldHandoverDeadlineRequired;
    case _Step0Field.boatArrival:
      return l10n.tripPublishBoatArrivalRequired;
  }
}

/// Champs obligatoires de l'étape 1.
enum _Step1Field { pickupAddress, deliveryAddress }

/// Message affiché sous le champ [f], même principe que [_step0FieldMessage].
String _step1FieldMessage(AppLocalizations l10n, _Step1Field f) {
  switch (f) {
    case _Step1Field.pickupAddress:
      return l10n.tripPublishFieldPickupAddressRequired;
    case _Step1Field.deliveryAddress:
      return l10n.tripPublishFieldDeliveryAddressRequired;
  }
}

// ─── Locked banner & locked-mode helpers ─────────────────────────────────────

/// Trajet dédié à une demande par bateau pour un voyageur sans badge GP Pro :
/// le bateau est réservé aux transporteurs vérifiés, « Continuer » reste grisé.
class _LockedBoatBlockedNote extends StatelessWidget {
  const _LockedBoatBlockedNote({required this.onRequestBadge});
  final VoidCallback onRequestBadge;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      key: const Key('locked-boat-blocked-note'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyStatusBanner(
          type: DonyStatusBannerType.warning,
          message: l.tripPublishLockedBoatBlocked,
        ),
        const SizedBox(height: DonySpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: onRequestBadge,
            child: Text(l.tripPublishModeBoatBadgeLink),
          ),
        ),
      ],
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.lockContext});
  final LockedTripContext lockContext;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
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
                  l10n.tripPublishLockedBannerTitle,
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.tripPublishLockedBannerSubtitle,
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

/// Devise d'un trajet en modification (FLUTTER-KV) : sélecteur tant que le
/// serveur la déclare modifiable, explication courte une fois figée, rien
/// avec un back qui ne sert pas `currencyEditable`.
class _EditCurrencySection extends StatelessWidget {
  const _EditCurrencySection({
    required this.editableNotifier,
    required this.currencyNotifier,
  });

  final ValueNotifier<bool?> editableNotifier;
  final ValueNotifier<SupportedCurrency> currencyNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: editableNotifier,
      builder: (context, editable, _) {
        if (editable == true) {
          return Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child: CurrencySelectionBanner(currencyNotifier: currencyNotifier),
          );
        }
        if (editable == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.base),
          child: Row(
            key: const Key('trip-edit-currency-locked-hint'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Text(
                  context.l10n.tripEditCurrencyLockedHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Carte « Créer avec l'IA », puis bandeau « Rempli par l'IA » avec
/// « Reparler » une fois le formulaire rempli. Première étape seulement.
class _AiTripEntry extends StatelessWidget {
  const _AiTripEntry({
    required this.availability,
    required this.filled,
    required this.currentStepNotifier,
    required this.firstStep,
    required this.onOpen,
  });

  final AiFormDraftAvailabilityCubit availability;
  final AiFilledFieldsCubit filled;
  final ValueListenable<TripFormStep> currentStepNotifier;
  final TripFormStep firstStep;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TripFormStep>(
    valueListenable: currentStepNotifier,
    builder: (context, step, _) {
      if (step != firstStep) return const SizedBox.shrink();
      return BlocBuilder<AiFilledFieldsCubit, Set<String>>(
        bloc: filled,
        builder: (context, fields) => fields.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(bottom: DonySpacing.base),
                child: AiFilledBanner(onTalkAgain: onOpen),
              )
            : AiEntryGate(
                availability: availability,
                padding: const EdgeInsets.only(bottom: DonySpacing.base),
                child: AiEntryCard(kind: AiFormKind.trip, onPressed: onOpen),
              ),
      );
    },
  );
}
