import 'dart:async';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/currency_publish_banner.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_step_indicator.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_sheet.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

abstract final class PackageRequestCreateWizard {
  static bool requiresEditWarning(PackageRequest? initial) =>
      initial != null && initial.status == PackageRequestStatus.negotiating;

  /// [initial] non-null → ouvre le wizard en mode édition (pré-rempli).
  static Future<void> show(
    BuildContext context, {
    PackageRequest? initial,
  }) async {
    if (requiresEditWarning(initial)) {
      final confirmed = await DonyDialog.show(
        context,
        title: 'Modifier votre demande ?',
        message:
            'Des voyageurs négocient actuellement cette demande. La '
            'modifier annulera toutes les offres en cours. Ils devront vous '
            'reproposer un trajet.',
        confirmLabel: 'Modifier quand même',
        cancelLabel: 'Annuler',
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
      final confirmed = await DonyDialog.show(
        context,
        title: 'Modifier votre demande ?',
        message:
            'Des voyageurs négocient actuellement cette demande. La '
            'modifier annulera toutes les offres en cours. Ils devront vous '
            'reproposer un trajet.',
        confirmLabel: 'Modifier quand même',
        cancelLabel: 'Annuler',
        variant: DonyDialogVariant.destructive,
        icon: Icons.warning_amber_rounded,
      );
      if (confirmed != true || !context.mounted) return null;
    }
    return context.push<bool>('/package-requests/new', extra: request);
  }
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class PackageRequestCreateScreen extends StatefulWidget {
  const PackageRequestCreateScreen({super.key, this.initial});

  /// Non-null en mode édition.
  final PackageRequest? initial;

  @override
  State<PackageRequestCreateScreen> createState() =>
      _PackageRequestCreateScreenState();
}

class _PackageRequestCreateScreenState
    extends State<PackageRequestCreateScreen> {
  final _step1Key = GlobalKey<Step1TrajetColisState>();
  final _step2Key = GlobalKey<Step2DetailsState>();
  final _step3Key = GlobalKey<Step3RecapBudgetState>();

  SupportedCurrency? get _activeCurrency => ActiveCurrency.fromHive(
        getIt.isRegistered<HiveService>() ? getIt<HiveService>() : null,
      );

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
    return _step1Key.currentState?.hasUnsubmittedInput ?? false;
  }

  /// Sortie demandée depuis l'étape 0 (croix ou retour système).
  Future<void> _handleExitRequest(PackageRequestFormState state) async {
    final dirty = _isDirty(state);
    if (!dirty) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<PackageRequestFormBloc>(param1: widget.initial),
        ),
        BlocProvider(
          create: (_) {
            final cubit = getIt<PackageRequestPhotosCubit>();
            if (widget.initial != null && widget.initial!.photos.isNotEmpty) {
              cubit.seed(widget.initial!.photos);
            }
            return cubit;
          },
        ),
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
      final isEditing = state.isEditing;
      final isDraft =
          state.createdRequest!.status == PackageRequestStatus.draft;
      final requestId = state.createdRequest!.id;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (routeContext) => DonySuccessScreen(
            mascotteType: DonyMascotteType.succes,
            title: isDraft
                ? 'Brouillon enregistré !'
                : isEditing
                ? 'Demande modifiée !'
                : 'Demande publiée !',
            subtitle: isDraft
                ? 'Tu pourras la publier quand tu le souhaites.'
                : isEditing
                ? 'Tes modifications sont en ligne.'
                : 'Les voyageurs sont notifiés. Tu recevras des offres '
                      'très vite.',
            ctaLabel: isDraft ? 'Voir mon brouillon' : 'Voir ma demande',
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
          ),
        ),
      );
    } else if (state.submissionStatus == FormSubmissionStatus.error &&
        state.draftLimitMessage != null) {
      unawaited(_handleDraftLimitReached(context, state.draftLimitMessage!));
    } else if (state.submissionStatus == FormSubmissionStatus.error) {
      ErrorPresenter.show(
        context,
        state.errorMessage ?? 'Erreur lors de la création',
      );
    }
  }

  Future<void> _handleDraftLimitReached(
    BuildContext context,
    String message,
  ) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Limite de brouillons atteinte',
      message: message,
      confirmLabel: 'Passer en PRO',
      cancelLabel: 'Plus tard',
    );
    if (confirmed == true && context.mounted) {
      unawaited(context.push('/profile/upgrade-to-pro'));
    }
  }

  Widget _buildScaffold(BuildContext context, PackageRequestFormState state) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final title = switch (state.currentStep) {
      0 => state.isEditing ? 'Modifier la demande' : 'Nouvelle demande',
      1 => 'Ton colis',
      _ => 'Dernière étape',
    };

    _initialSignature ??= _signatureOf(state);

    return PopScope(
      // Aux étapes 1 et 2, le retour recule d'une étape. À l'étape 0 il sort
      // de l'écran : on n'autorise le pop direct que si rien n'a été saisi.
      canPop: state.currentStep == 0 && !_isDirty(state),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (state.currentStep > 0) {
          context.read<PackageRequestFormBloc>().add(const FormStepBack());
        } else {
          unawaited(_handleExitRequest(state));
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
                unawaited(_handleExitRequest(state));
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
                0 => Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        DonySpacing.base,
                        DonySpacing.sm,
                        DonySpacing.base,
                        0,
                      ),
                      child: ContextualTutorialCard(
                        context: TutorialContext.requestPublish,
                      ),
                    ),
                    if (!state.isEditing)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DonySpacing.base,
                          DonySpacing.base,
                          DonySpacing.base,
                          0,
                        ),
                        child: CurrencyPublishBanner.fromHive(
                          hiveService: getIt.isRegistered<HiveService>()
                              ? getIt<HiveService>()
                              : null,
                        ),
                      ),
                    Expanded(
                      child: Step1TrajetColis(
                        key: _step1Key,
                        canContinueNotifier: _canContinueNotifier,
                      ),
                    ),
                  ],
                ),
                1 => Step2Details(
                  key: _step2Key,
                  canContinueNotifier: _canContinueNotifier,
                ),
                _ => Step3RecapBudget(
                  key: _step3Key,
                  canContinueNotifier: _canContinueNotifier,
                  currency: _activeCurrency,
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
          currency: _activeCurrency,
          onConfirm: () {
            Navigator.of(context, rootNavigator: true).pop();
            _step3Key.currentState?.submit();
          },
          onSaveDraft: widget.initial == null ||
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
        boxShadow: [
          BoxShadow(
            color: DonyColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, -4),
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
            Text(
              'En publiant, tu acceptes les CGU',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          if (currentStep > 0)
            Row(
              children: [
                SizedBox(
                  width: 112,
                  child: DonyButton(
                    label: 'Retour',
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
                          ? 'Publication…'
                          : isFinalStep
                          ? 'Aperçu'
                          : 'Continuer',
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
                label: isSubmitting ? 'Publication…' : 'Continuer',
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
