import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_step_indicator.dart';
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
            'modifier annulera toutes les offres en cours — ils devront vous '
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

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<PackageRequestFormBloc>(param1: widget.initial),
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

  void _onStateChange(
    BuildContext context,
    PackageRequestFormState state,
  ) {
    if (state.submissionStatus == FormSubmissionStatus.success &&
        state.createdRequest != null) {
      final isEditing = state.isEditing;
      final requestId = state.createdRequest!.id;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (routeContext) => DonySuccessScreen(
          mascotteType: DonyMascotteType.tenantColis,
          title: isEditing ? 'Demande modifiée !' : 'Demande publiée !',
          subtitle: isEditing
              ? 'Tes modifications sont en ligne.'
              : 'Les voyageurs sont notifiés — tu recevras des offres '
                  'très vite.',
          ctaLabel: 'Voir ma demande',
          onCta: () {
            // Le contexte de la route succès (routeContext) reste monté
            // sous le Navigator racine après le pop ci-dessous — on capture
            // donc le GoRouter AVANT de popper, pour éviter « Looking up a
            // deactivated widget's ancestor is unsafe » (même classe de bug
            // que le fix bid-payé, feb86b71).
            final router = GoRouter.of(routeContext);
            Navigator.of(routeContext).pop(); // ferme DonySuccessScreen
            context.pop(); // ferme le wizard — aucune valeur attendue par
            // les appelants (context.push<void>(...), refresh inconditionnel
            // après l'await, jamais gaté sur la valeur du pop)
            router.push('/package-requests/$requestId');
          },
          // Pas d'onClose custom : aucun appelant ne gate son refresh sur la
          // valeur du pop (my_package_requests_screen, envoyer_hub_screen et
          // package_request_public_detail_screen rafraîchissent tous de
          // façon inconditionnelle après l'await) — le comportement par
          // défaut (X → go('/home')) est donc sûr, comme pour
          // create_trip_screen/create_announcement_screen.
          analyticsContext: 'package_request_published',
        ),
      ));
    } else if (state.submissionStatus == FormSubmissionStatus.error) {
      ErrorPresenter.show(
        context,
        state.errorMessage ?? 'Erreur lors de la création',
      );
    }
  }

  Widget _buildScaffold(
    BuildContext context,
    PackageRequestFormState state,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final title = switch (state.currentStep) {
      0 => state.isEditing ? 'Modifier la demande' : 'Nouvelle demande',
      1 => 'Ton colis',
      _ => 'Dernière étape',
    };

    return PopScope(
      canPop: state.currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.read<PackageRequestFormBloc>().add(const FormStepBack());
        }
      },
      child: Scaffold(
        backgroundColor: DonyColors.sand100,
        appBar: AppBar(
          backgroundColor: DonyColors.sand100,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Retour',
            onPressed: () {
              if (state.currentStep > 0) {
                context
                    .read<PackageRequestFormBloc>()
                    .add(const FormStepBack());
              } else {
                context.pop();
              }
            },
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
              ),
              child: DonyIcon('chevron-left', size: 20, color: cs.primary),
            ),
          ),
          title: Text(
            title,
            style: tt.titleLarge?.copyWith(
              color: DonyColors.textPrimary,
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
                Divider(height: 1, color: DonyColors.neutral200),
                WizardStepIndicator(currentStep: state.currentStep),
              ],
            ),
          ),
        ),
        body: switch (state.currentStep) {
          0 => Step1TrajetColis(key: _step1Key),
          1 => Step2Details(key: _step2Key),
          _ => Step3RecapBudget(key: _step3Key),
        },
        bottomNavigationBar: _StickyCta(
          currentStep: state.currentStep,
          isSubmitting:
              state.submissionStatus == FormSubmissionStatus.submitting,
          onPressed: () => _onCtaPressed(context, state),
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
        _step3Key.currentState?.submit();
    }
  }
}

// ─── Sticky CTA ─────────────────────────────────────────────────────────────

class _StickyCta extends StatelessWidget {
  const _StickyCta({
    required this.currentStep,
    required this.isSubmitting,
    required this.onPressed,
  });

  final int currentStep;
  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isFinalStep = currentStep == 2;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: DonyColors.sand100,
        border: Border(top: BorderSide(color: DonyColors.neutral200)),
        boxShadow: [
          BoxShadow(
            color: DonyColors.sand400.withValues(alpha: 0.18),
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
                color: DonyColors.textMuted,
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
                        : () => context
                            .read<PackageRequestFormBloc>()
                            .add(const FormStepBack()),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: DonyButton(
                    label: isSubmitting
                        ? 'Publication…'
                        : isFinalStep
                        ? 'Publier ma demande'
                        : 'Continuer',
                    iconRightAsset: isFinalStep ? 'send' : 'arrow-right',
                    onPressed: isSubmitting ? null : onPressed,
                    isLoading: isSubmitting,
                  ),
                ),
              ],
            )
          else
            DonyButton(
              label: isSubmitting ? 'Publication…' : 'Continuer',
              iconRightAsset: 'arrow-right',
              onPressed: isSubmitting ? null : onPressed,
              isLoading: isSubmitting,
            ),
        ],
      ),
    );
  }
}
