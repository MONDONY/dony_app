import 'dart:async';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/currency_publish_banner.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_filled_fields_cubit.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_availability_cubit.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/package_request_ai_draft_mapper.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_form_draft_launcher.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_entry_card.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_filled_banner.dart';
import 'package:dony/features/billing/presentation/pro_limit_dialog.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_draft.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_duplicate.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_step_indicator.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/wizard_currency.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_sheet.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_active.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Réexporté pour les appelants existants (router, DI, T9) qui importaient
// PackageRequestDuplicate via cet écran avant son déplacement dans data/models.
export 'package:dony/features/package_request/data/models/package_request_duplicate.dart';

abstract final class PackageRequestCreateWizard {
  static bool requiresEditWarning(PackageRequest? initial) =>
      initial != null && initial.status == PackageRequestStatus.negotiating;

  /// [initial] non-null → ouvre le wizard en mode édition (pré-rempli).
  static Future<void> show(
    BuildContext context, {
    PackageRequest? initial,
  }) async {
    if (requiresEditWarning(initial)) {
      final l10n = context.l10n;
      final confirmed = await DonyDialog.show(
        context,
        title: l10n.requestCreateEditWarningTitle,
        message: l10n.requestCreateEditWarningMessage,
        confirmLabel: l10n.requestCreateEditWarningConfirm,
        variant: DonyDialogVariant.destructive,
        icon: Icons.warning_amber_rounded,
      );
      if (confirmed != true || !context.mounted) return;
    }
    await context.push<void>('/package-requests/new', extra: initial);
  }

  /// Édition depuis « Ma demande » — retourne `true` si la demande a été
  /// modifiée, pour que l'appelant sache s'il doit recharger.
  static Future<bool?> showEditing(
    BuildContext context,
    PackageRequest request,
  ) async {
    if (requiresEditWarning(request)) {
      final l10n = context.l10n;
      final confirmed = await DonyDialog.show(
        context,
        title: l10n.requestCreateEditWarningTitle,
        message: l10n.requestCreateEditWarningMessage,
        confirmLabel: l10n.requestCreateEditWarningConfirm,
        variant: DonyDialogVariant.destructive,
        icon: Icons.warning_amber_rounded,
      );
      if (confirmed != true || !context.mounted) return null;
    }
    return context.push<bool>('/package-requests/new', extra: request);
  }

  /// Création pré-remplie depuis une demande existante (dupliquer, republier).
  /// Le back n'accepte `publish` que sur un brouillon : republier une demande
  /// déjà publiée (expirée, refusée, etc.) passe donc par une toute nouvelle
  /// demande, sans photos (une clé R2 n'appartient qu'à une seule demande).
  static Future<bool?> showDuplicate(
    BuildContext context,
    PackageRequest source, {
    bool clearDate = false,
  }) => context.push<bool>(
    '/package-requests/new',
    extra: PackageRequestDuplicate(source, clearDate: clearDate),
  );
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class PackageRequestCreateScreen extends StatefulWidget {
  const PackageRequestCreateScreen({
    super.key,
    this.initial,
    this.duplicating,
    this.resuming,
  });

  /// Non-null en mode édition.
  final PackageRequest? initial;

  /// Non-null en création pré-remplie (dupliquer, republier). Mutuellement
  /// exclusif avec [initial] : le router ne peuple jamais les deux.
  final PackageRequestDuplicate? duplicating;

  /// Non-null quand l'expéditeur reprend son brouillon local depuis la
  /// feuille des brouillons. Création seulement.
  final PackageRequestDraftResume? resuming;

  @override
  State<PackageRequestCreateScreen> createState() =>
      _PackageRequestCreateScreenState();
}

class _PackageRequestCreateScreenState
    extends State<PackageRequestCreateScreen> {
  var _step1Key = GlobalKey<Step1TrajetColisState>();
  var _step2Key = GlobalKey<Step2DetailsState>();
  var _step3Key = GlobalKey<Step3RecapBudgetState>();

  /// `draftRevision` du bloc pour lequel les clés d'étape ont été créées. Une
  /// reprise de brouillon l'incrémente : de nouvelles clés forcent les étapes
  /// à relire l'état du bloc, ce qu'elles ne font qu'à leur `initState`.
  int _stepKeysRevision = 0;

  /// Brouillon local proposé en création seulement : modifier une demande ou
  /// en dupliquer une part d'un contenu déjà connu.
  late final bool _draftsEnabled =
      widget.initial == null && widget.duplicating == null;

  /// Porté par l'écran (et non créé par un provider) : la sortie et le
  /// bouton brouillon s'en servent depuis ce `State`, au-dessus des providers.
  late final FormDraftCubit? _draftCubit = _draftsEnabled
      ? getIt<FormDraftCubit>(param1: FormDraftKind.packageRequest)
      : null;

  /// Résolue une fois : la devise active ne peut pas changer pendant qu'un
  /// formulaire de publication est ouvert, et ce getter était réévalué
  /// jusque dans un `itemBuilder` (lookup GetIt + lecture Hive par ligne).
  late final SupportedCurrency? _activeCurrency = ActiveCurrency.current;

  /// « Créer avec l'IA » : création seulement, ni édition, ni duplication, ni
  /// reprise de brouillon (spec §2.2).
  late final AiFormDraftAvailabilityCubit? _aiAvailability =
      widget.initial == null &&
          widget.duplicating == null &&
          widget.resuming == null
      ? getIt<AiFormDraftAvailabilityCubit>()
      : null;

  /// Champs remplis par l'IA : marque « IA » et bandeau.
  final AiFilledFieldsCubit _aiFilled = AiFilledFieldsCubit();

  @override
  void initState() {
    super.initState();
    final aiAvailability = _aiAvailability;
    if (aiAvailability != null) unawaited(aiAvailability.refresh());
    // Entrée du tunnel de création, comme `trip_create_started` côté trajet :
    // sans elle, on voyait les demandes créées, jamais les formulaires ouverts.
    if (widget.initial == null && getIt.isRegistered<AnalyticsService>()) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.packageRequestCreateStarted,
          properties: {
            'source': widget.duplicating != null
                ? 'duplicate'
                : widget.resuming != null
                ? 'draft'
                : 'new',
          },
        ),
      );
    }
  }

  /// Ouvre « Créer avec l'IA » puis applique le brouillon par
  /// `FormDraftRestored`, posé sur l'état courant, à l'étape 1.
  Future<void> _openAiDraft(BuildContext formContext) async {
    final bloc = formContext.read<PackageRequestFormBloc>();
    final outcome = await getIt<AiFormDraftLauncher>().open(
      formContext,
      kind: AiFormKind.packageRequest,
      defaultCurrency: (bloc.state.currency ?? _activeCurrency)?.code,
    );
    if (!mounted || outcome == null || bloc.isClosed) return;
    bloc.add(
      FormDraftRestored(
        PackageRequestAiDraftMapper.toFormState(
          outcome.draft,
          base: PackageRequestAiDraftMapper.withStep1Input(
            bloc.state,
            _step1Key.currentState?.draftInput,
          ),
          catalogLabels: [for (final c in fallbackCatalog) c.label],
        ),
        fromAi: true,
      ),
    );
    // « Reparler » complète : les marques de la passe précédente restent.
    _aiFilled.markFilled({..._aiFilled.state, ...outcome.filledFields});
  }

  /// Vrai quand l'étape courante a tous ses champs obligatoires renseignés.
  ///
  /// Porté par l'écran plutôt que par chaque étape : c'est lui qui possède le
  /// bouton « Continuer », et les étapes sont détruites/reconstruites à chaque
  /// changement d'index. Chaque étape le met à jour depuis son `initState` puis
  /// à chaque saisie.
  final ValueNotifier<bool> _canContinueNotifier = ValueNotifier<bool>(false);

  /// Signature du formulaire à l'ouverture, capturée au premier build.
  /// Sert à ne demander confirmation de sortie que si l'utilisateur a
  /// réellement saisi quelque chose.
  String? _initialSignature;

  /// Évite d'empiler deux dialogues si le retour système est répété.
  bool _confirmingExit = false;

  /// État saisissable de la demande, hors mécanique de navigation et de
  /// soumission (`currentStep`, `submissionStatus`, etc.).
  ///
  /// Les photos n'y figurent pas : elles vivent à l'étape 2, qu'on n'atteint
  /// qu'après avoir renseigné l'étape 1. Le formulaire est donc déjà « sale »
  /// avant qu'une photo puisse exister.
  String _signatureOf(PackageRequestFormState s) => [
    s.departureCity,
    s.arrivalCity,
    s.desiredDate,
    s.dateToleranceDays,
    s.transportMode,
    s.weightKg,
    s.parcelSize,
    (s.categories.toList()..sort()).join(','),
    s.description,
    s.targetPriceEur,
    s.photoUrl,
    s.pickupNeighborhood,
    s.deliveryNeighborhood,
    s.negotiable,
    (s.acceptedPaymentMethods.map((e) => e.name).toList()..sort()).join(','),
    s.totalBudgetEur,
  ].join('|');

  /// Vrai si quelque chose a été saisi, dans le bloc ou dans l'étape courante.
  ///
  /// Les étapes ne poussent leur contenu au bloc qu'à leur validation : se
  /// fier au seul état du bloc laisserait filer une étape 1 en cours de
  /// remplissage.
  bool _isDirty(PackageRequestFormState state) {
    if (_initialSignature != null && _signatureOf(state) != _initialSignature) {
      return true;
    }
    return (_step1Key.currentState?.hasUnsubmittedInput ?? false) ||
        (_step2Key.currentState?.hasUnsubmittedInput ?? false);
  }

  /// Sortie demandée depuis l'étape 0 (croix ou retour système).
  Future<void> _handleExitRequest(
    BuildContext formContext,
    PackageRequestFormState state,
  ) async {
    final dirty = _isDirty(state);
    if (!dirty) {
      _leave();
      return;
    }
    if (_confirmingExit) return;
    _confirmingExit = true;
    if (!_draftsEnabled) {
      final confirmed = await DonyDialog.confirmDiscard(context);
      _confirmingExit = false;
      if (!mounted || confirmed != true) return;
      _leave();
      return;
    }
    final choice = await DonyDialog.confirmExitWithDraft(context);
    _confirmingExit = false;
    if (!mounted || !formContext.mounted || choice == null) return;
    switch (choice) {
      case DraftExitChoice.save:
        await _saveDraftAndLeave(formContext, FormDraftSource.exitDialog);
      case DraftExitChoice.discard:
        await _draftCubit!.discard(source: FormDraftSource.exitDialog);
        if (mounted) _leave();
    }
  }

  /// Saisie de l'étape affichée, que l'étape ne remonte au bloc qu'à sa
  /// validation. L'étape budget, elle, écrit dans le bloc à chaque frappe.
  Map<String, dynamic> _currentStepInput(int step) => switch (step) {
    0 => _step1Key.currentState?.draftInput ?? const {},
    1 => _step2Key.currentState?.draftInput ?? const {},
    _ => const {},
  };

  /// Garde la saisie en brouillon local, à l'étape où elle en est, puis
  /// quitte le formulaire. En cas d'échec, l'utilisateur reste sur sa saisie.
  Future<void> _saveDraftAndLeave(
    BuildContext formContext,
    FormDraftSource source,
  ) async {
    final state = formContext.read<PackageRequestFormBloc>().state;
    final data = PackageRequestFormDraft.encode(
      state,
      stepInput: _currentStepInput(state.currentStep),
      photos: formContext.read<PackageRequestPhotosCubit>().state,
    );
    final saved = await _draftCubit!.save(data, source: source);
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
    _leave();
  }

  /// Bouton « Brouillon » de la barre, disponible à chaque étape.
  void _onSaveDraftPressed(
    BuildContext formContext,
    PackageRequestFormState state,
  ) {
    if (!_isDirty(state)) {
      DonySnackbar.show(
        context,
        message: context.l10n.formDraftNothingToSaveMessage,
      );
      return;
    }
    unawaited(_saveDraftAndLeave(formContext, FormDraftSource.appBar));
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _canContinueNotifier.dispose();
    unawaited(_draftCubit?.close());
    unawaited(_aiFilled.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final bloc = getIt<PackageRequestFormBloc>(
              param1: widget.initial,
              param2: widget.duplicating,
            );
            final resuming = widget.resuming;
            if (resuming != null) {
              // Traité avant la première saisie possible ; draftRevision
              // recrée les étapes déjà construites sur l'état vide.
              bloc.add(
                FormDraftRestored(
                  PackageRequestFormDraft.decode(resuming.data),
                ),
              );
            }
            return bloc;
          },
        ),
        BlocProvider(
          create: (_) {
            final cubit = getIt<PackageRequestPhotosCubit>();
            if (widget.initial != null && widget.initial!.photos.isNotEmpty) {
              cubit.seed(widget.initial!.photos);
            }
            final resuming = widget.resuming;
            if (resuming != null) {
              cubit.restoreDraft(
                PackageRequestFormDraft.decodePhotos(resuming.data),
              );
            }
            return cubit;
          },
        ),
        // Accepter le mobile money exige un compte mobile money configuré
        // (FLUTTER-B2) : l'étape budget en a besoin pour bloquer la
        // publication et proposer le lien d'activation.
        BlocProvider<MobileMoneyAccountBloc>(
          create: (_) =>
              getIt<MobileMoneyAccountBloc>()
                ..add(const MobileMoneyAccountsRequested()),
        ),
        BlocProvider<AiFilledFieldsCubit>.value(value: _aiFilled),
        if (_draftCubit != null)
          BlocProvider<FormDraftCubit>.value(value: _draftCubit),
      ],
      child: BlocConsumer<PackageRequestFormBloc, PackageRequestFormState>(
        listener: _onStateChange,
        builder: _buildScaffold,
      ),
    );
  }

  void _onStateChange(BuildContext context, PackageRequestFormState state) {
    if (state.submissionStatus == FormSubmissionStatus.success &&
        state.createdRequest != null) {
      // Publiée ou gardée en brouillon serveur : la saisie locale n'a plus
      // lieu d'être proposée.
      if (_draftCubit != null) unawaited(_draftCubit.clear());
      final l10n = context.l10n;
      final isEditing = state.isEditing;
      final isDraft =
          state.createdRequest!.status == PackageRequestStatus.draft;
      final requestId = state.createdRequest!.id;
      final created = state.createdRequest!;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (routeContext) => DonySuccessScreen(
            mascotteType: DonyMascotteType.succes,
            title: isDraft
                ? l10n.requestCreateDraftSavedTitle
                : isEditing
                ? l10n.requestCreateEditedTitle
                : l10n.requestCreatePublishedTitle,
            subtitle: isDraft
                ? l10n.requestCreateDraftSavedSubtitle
                : isEditing
                ? l10n.requestCreateEditedSubtitle
                : l10n.requestCreatePublishedSubtitle,
            ctaLabel: isDraft
                ? l10n.requestCreateViewDraftCta
                : l10n.requestCreateViewRequestCta,
            onCta: () {
              // Le contexte de la route succès (routeContext) reste monté
              // sous le Navigator racine après le pop ci-dessous — on capture
              // donc le GoRouter AVANT de popper, pour éviter « Looking up a
              // deactivated widget's ancestor is unsafe » (même classe de bug
              // que le fix bid-payé, feb86b71).
              final router = GoRouter.of(routeContext);
              Navigator.of(routeContext).pop(); // ferme DonySuccessScreen
              if (isEditing) {
                // Édition : l'appelant (showEditing() depuis « Ma demande »,
                // ou tout autre appelant de show(context, initial: ...)) est
                // déjà sur/au-dessus de la demande concernée et se recharge
                // après l'await — ne pas repousser une nouvelle route détail
                // par-dessus, ça doublonnerait la pile de navigation (le même
                // détail deux fois, ou un détail plein écran par-dessus une
                // sheet restée ouverte).
                context.pop(true);
              } else {
                context.pop(); // ferme le wizard — aucune valeur attendue par
                // les autres appelants (context.push<void>(...), refresh
                // inconditionnel après l'await, jamais gaté sur la valeur du pop)
                router.push('/package-requests/$requestId');
              }
            },
            // Pas d'onClose custom : aucun appelant ne gate son refresh sur la
            // valeur du pop (my_package_requests_screen, envoyer_hub_screen et
            // package_request_public_detail_screen rafraîchissent tous de
            // façon inconditionnelle après l'await) — le comportement par
            // défaut (X → go('/home')) est donc sûr, comme pour
            // create_trip_screen.
            analyticsContext: isDraft
                ? 'package_request_draft_saved'
                : 'package_request_published',
            // Comme pour un trajet : à la publication, l'expéditeur peut
            // diffuser tout de suite son affiche (image, lien et légende) pour
            // trouver un voyageur hors de l'application. Ni au brouillon, qui
            // n'est pas public, ni à l'édition. Le GoRouter est capturé AVANT
            // les pops, routeContext étant démonté ensuite.
            secondaryLabel: isDraft || isEditing
                ? null
                : l10n.tripPublishSuccessShareCta,
            onSecondary: isDraft || isEditing
                ? null
                : () {
                    final router = GoRouter.of(routeContext);
                    Navigator.of(routeContext).pop();
                    context.pop();
                    router.push(
                      '/package-requests/$requestId/affiche',
                      extra: created,
                    );
                  },
          ),
        ),
      );
    } else if (state.submissionStatus == FormSubmissionStatus.error &&
        state.draftLimitMessage != null) {
      unawaited(
        _handleDraftLimitReached(
          context,
          ErrorPresenter.resolve(state.error, l10n: context.l10n).message,
        ),
      );
    } else if (state.submissionStatus == FormSubmissionStatus.error &&
        state.formError == PackageRequestFormError.budgetRequired) {
      // Erreur connue de l'app elle-même (pas du serveur) : sa traduction,
      // jamais un texte porté par l'état.
      DonySnackbar.show(
        context,
        message: context.l10n.requestBudgetRequired,
        type: DonySnackbarType.warning,
      );
    } else if (state.submissionStatus == FormSubmissionStatus.error) {
      // L'exception typée, jamais son texte : un texte nu ressort du
      // présenteur en « Erreur réseau » quel que soit le statut HTTP, et le
      // 422 « budget hors bornes » d'une demande en franc CFA était illisible.
      ErrorPresenter.show(
        context,
        state.error ??
            state.errorMessage ??
            context.l10n.requestCreateGenericError,
      );
    }
  }

  Future<void> _handleDraftLimitReached(
    BuildContext context,
    String message,
  ) async {
    final goPro = await showProLimitReachedDialog(
      context,
      title: context.l10n.requestCreateDraftLimitTitle,
      message: message,
    );
    if (goPro && context.mounted) {
      unawaited(context.push('/profile/upgrade-to-pro'));
    }
  }

  Widget _buildScaffold(BuildContext context, PackageRequestFormState state) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;

    // Un titre par contenu d'étape, pas un mélange de contenu et de position :
    // le badge « 2 / 3 » dit déjà où l'on en est.
    final title = switch (state.currentStep) {
      0 =>
        state.isEditing
            ? l10n.requestCreateStepTitleEdit
            : l10n.requestCreateStepTitleTrip,
      1 => l10n.requestCreateStepTitlePackage,
      _ => l10n.requestCreateStepTitleBudget,
    };

    _initialSignature ??= _signatureOf(state);
    if (state.draftRevision != _stepKeysRevision) {
      _stepKeysRevision = state.draftRevision;
      _step1Key = GlobalKey<Step1TrajetColisState>();
      _step2Key = GlobalKey<Step2DetailsState>();
      _step3Key = GlobalKey<Step3RecapBudgetState>();
    }

    return PopScope(
      // Aux étapes 1 et 2, le retour recule d'une étape. À l'étape 0 il sort
      // de l'écran : on n'autorise le pop direct que si rien n'a été saisi.
      canPop: state.currentStep == 0 && !_isDirty(state),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (state.currentStep > 0) {
          context.read<PackageRequestFormBloc>().add(const FormStepBack());
        } else {
          unawaited(_handleExitRequest(context, state));
        }
      },
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: DonyAppBarBackButton(
            onBack: () {
              if (state.currentStep > 0) {
                context.read<PackageRequestFormBloc>().add(
                  const FormStepBack(),
                );
              } else {
                unawaited(_handleExitRequest(context, state));
              }
            },
          ),
          title: Text(
            title,
            style: tt.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: false,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: DonySpacing.base),
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.sm + 2,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(color: cs.primary),
              ),
              child: Text(
                '${state.currentStep + 1} / 3',
                style: tt.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ),
            if (_draftsEnabled)
              IconButton(
                key: const Key('request-save-draft'),
                tooltip: l10n.formDraftSaveTooltip,
                onPressed:
                    state.submissionStatus == FormSubmissionStatus.submitting
                    ? null
                    : () => _onSaveDraftPressed(context, state),
                icon: DonyIcon('notebook-pen', color: cs.primary, size: 22),
              ),
            const DonyFeedbackButton(),
          ],
          bottom: PreferredSize(
            // 1 (divider) + 8 (top pad) + 4 (bar) + 12 (bottom pad)
            preferredSize: const Size.fromHeight(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(height: 1, color: cs.outline),
                WizardStepIndicator(currentStep: state.currentStep),
              ],
            ),
          ),
        ),
        resizeToAvoidBottomInset: true,
        // La CTA sticky est dans `body` (pas `bottomNavigationBar`) : Flutter
        // ne remonte pas fiablement `bottomNavigationBar` au-dessus du
        // clavier, ce qui la cachait derrière sur les steps avec champs texte
        // (poids, prix, description). Même fix que phone_auth_screen.dart.
        body: Column(
          children: [
            Expanded(
              child: switch (state.currentStep) {
                // Rien n'est épinglé au-dessus de l'étape : la carte de
                // tutoriel et la bannière de devise vivaient hors du
                // `SingleChildScrollView` et mangeaient de la hauteur pendant
                // toute la saisie, clavier déployé. Elles passent en tête du
                // contenu défilant.
                0 => Step1TrajetColis(
                  key: _step1Key,
                  canContinueNotifier: _canContinueNotifier,
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_aiAvailability case final availability?)
                        BlocBuilder<AiFilledFieldsCubit, Set<String>>(
                          bloc: _aiFilled,
                          builder: (_, fields) => fields.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: DonySpacing.base,
                                  ),
                                  child: AiFilledBanner(
                                    onTalkAgain: () =>
                                        unawaited(_openAiDraft(context)),
                                  ),
                                )
                              : AiEntryGate(
                                  availability: availability,
                                  padding: const EdgeInsets.only(
                                    bottom: DonySpacing.base,
                                  ),
                                  child: AiEntryCard(
                                    kind: AiFormKind.packageRequest,
                                    onPressed: () =>
                                        unawaited(_openAiDraft(context)),
                                  ),
                                ),
                        ),
                      if (!state.isEditing) ...[
                        const SizedBox(height: DonySpacing.base),
                        // `_activeCurrency` est déjà résolue une fois pour
                        // tout le formulaire ; la factory `.active()` refaisait
                        // un lookup GetIt et une lecture Hive à chaque build.
                        // La devise du formulaire prime (duplication) : c'est
                        // elle qui part au backend, comme à l'étape 3.
                        CurrencyPublishBanner(
                          currency: state.currency ?? _activeCurrency,
                        ),
                      ],
                    ],
                  ),
                ),
                1 => Step2Details(
                  key: _step2Key,
                  canContinueNotifier: _canContinueNotifier,
                ),
                _ =>
                  BlocBuilder<MobileMoneyAccountBloc, MobileMoneyAccountState>(
                    builder: (context, mobileMoneyState) => Step3RecapBudget(
                      key: _step3Key,
                      canContinueNotifier: _canContinueNotifier,
                      currency: _activeCurrency,
                      mobileMoneyAccountActive: mobileMoneyAccountActiveFrom(
                        mobileMoneyState,
                      ),
                      // L'écran d'activation a sa propre instance du bloc :
                      // sans rechargement au retour, l'étape afficherait
                      // encore « non configuré » après l'activation.
                      onMobileMoneySetupReturned: () => context
                          .read<MobileMoneyAccountBloc>()
                          .add(const MobileMoneyAccountsRequested()),
                    ),
                  ),
              },
            ),
            _StickyCta(
              canContinueNotifier: _canContinueNotifier,
              currentStep: state.currentStep,
              isSubmitting:
                  state.submissionStatus == FormSubmissionStatus.submitting,
              onPressed: () => _onCtaPressed(context, state),
            ),
          ],
        ),
      ),
    );
  }

  void _onCtaPressed(BuildContext context, PackageRequestFormState state) {
    switch (state.currentStep) {
      case 0:
        _step1Key.currentState?.submit();
      case 1:
        _step2Key.currentState?.submit();
      default:
        PackageRequestPreviewSheet.show(
          context,
          formState: state,
          // Même devise que l'étape 3 et que le payload (FLUTTER-HB) : la
          // devise d'affichage du compte n'est qu'un repli.
          currency: resolveWizardCurrency(state, fallback: _activeCurrency),
          photoCount: context
              .read<PackageRequestPhotosCubit>()
              .readyKeys
              .length,
          onConfirm: () {
            Navigator.of(context, rootNavigator: true).pop();
            _step3Key.currentState?.submit();
          },
          onSaveDraft:
              widget.initial == null ||
                  widget.initial!.status == PackageRequestStatus.draft
              ? () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _step3Key.currentState?.submit(saveAsDraft: true);
                }
              : null,
        );
    }
  }
}

// ─── Mention CGU ────────────────────────────────────────────────────────────

/// Mention légale au-dessus du CTA de publication.
///
/// « CGU » était un mot ordinaire, ni souligné ni tappable, alors qu'on
/// demandait d'y consentir : le lien ouvre maintenant le même écran que
/// l'onboarding et les réglages.
class _CguNotice extends StatefulWidget {
  const _CguNotice();

  @override
  State<_CguNotice> createState() => _CguNoticeState();
}

class _CguNoticeState extends State<_CguNotice> {
  /// Un `TapGestureRecognizer` doit être libéré à la main : construit dans un
  /// `build()`, il fuirait à chaque reconstruction de la barre sticky.
  late final TapGestureRecognizer _cguTap = TapGestureRecognizer()
    ..onTap = () => unawaited(context.push('/legal/terms'));

  @override
  void dispose() {
    _cguTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final base = tt.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontSize: 12,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: l10n.requestCreateCguPrefix),
          TextSpan(
            text: l10n.requestCreateCguLink,
            style: base?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: cs.primary,
            ),
            recognizer: _cguTap,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ─── Sticky CTA ─────────────────────────────────────────────────────────────

class _StickyCta extends StatelessWidget {
  const _StickyCta({
    required this.currentStep,
    required this.isSubmitting,
    required this.onPressed,
    required this.canContinueNotifier,
  });

  final int currentStep;
  final bool isSubmitting;
  final VoidCallback onPressed;

  /// Grise le bouton tant que l'étape courante est incomplète. Un bouton actif
  /// qui refuse l'action se lit comme une panne, pas comme un champ oublié.
  final ValueListenable<bool> canContinueNotifier;

  @override
  Widget build(BuildContext context) {
    final isFinalStep = currentStep == 2;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
        boxShadow: const [
          BoxShadow(
            color: DonyColors.shadow,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.md,
        DonySpacing.lg,
        bottomInset + DonySpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFinalStep) ...[
            const _CguNotice(),
            const SizedBox(height: DonySpacing.sm),
          ],
          if (currentStep > 0)
            Row(
              children: [
                SizedBox(
                  width: 112,
                  child: DonyButton(
                    label: l10n.commonBack,
                    variant: DonyButtonVariant.secondary,
                    onPressed: isSubmitting
                        ? null
                        : () => context.read<PackageRequestFormBloc>().add(
                            const FormStepBack(),
                          ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: canContinueNotifier,
                    builder: (context, canContinue, _) => DonyButton(
                      label: isSubmitting
                          ? l10n.requestCreatePublishingLabel
                          : isFinalStep
                          ? l10n.requestCreatePreviewButton
                          : l10n.commonContinue,
                      iconRightAsset: 'arrow-right',
                      onPressed: (isSubmitting || !canContinue)
                          ? null
                          : onPressed,
                      isLoading: isSubmitting,
                    ),
                  ),
                ),
              ],
            )
          else
            ValueListenableBuilder<bool>(
              valueListenable: canContinueNotifier,
              builder: (context, canContinue, _) => DonyButton(
                label: isSubmitting
                    ? l10n.requestCreatePublishingLabel
                    : l10n.commonContinue,
                iconRightAsset: 'arrow-right',
                onPressed: (isSubmitting || !canContinue) ? null : onPressed,
                isLoading: isSubmitting,
              ),
            ),
        ],
      ),
    );
  }
}
