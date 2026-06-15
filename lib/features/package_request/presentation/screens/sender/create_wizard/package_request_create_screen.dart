import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_step_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Wizard 3 étapes — bottom sheet crème/terracotta (Proposition B).
abstract final class PackageRequestCreateWizard {
  /// [initial] non-null → ouvre le wizard en mode édition (pré-rempli).
  static Future<void> show(BuildContext context, {PackageRequest? initial}) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (sheetContext) {
        return BlocProvider(
          create: (_) => getIt<PackageRequestFormBloc>(param1: initial),
          child: const _WizardSheet(),
        );
      },
    );
  }
}

// ─── Router compat ──────────────────────────────────────────────────────────
class PackageRequestCreateScreen extends StatefulWidget {
  const PackageRequestCreateScreen({super.key});

  @override
  State<PackageRequestCreateScreen> createState() =>
      _PackageRequestCreateScreenState();
}

class _PackageRequestCreateScreenState
    extends State<PackageRequestCreateScreen> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await PackageRequestCreateWizard.show(context);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }
}

// ─── Sheet interne ──────────────────────────────────────────────────────────
class _WizardSheet extends StatefulWidget {
  const _WizardSheet();

  @override
  State<_WizardSheet> createState() => _WizardSheetState();
}

class _WizardSheetState extends State<_WizardSheet> {
  final _step1Key = GlobalKey<Step1TrajetColisState>();
  final _step2Key = GlobalKey<Step2DetailsState>();
  final _step3Key = GlobalKey<Step3RecapBudgetState>();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardInset = mq.viewInsets.bottom;
    final sheetHeight = (mq.size.height * 0.92) - keyboardInset;

    return BlocConsumer<PackageRequestFormBloc, PackageRequestFormState>(
      listener: (context, state) {
        if (state.submissionStatus == FormSubmissionStatus.success &&
            state.createdRequest != null) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.isEditing
                  ? 'Demande modifiée'
                  : 'Demande publiée — les voyageurs sont notifiés'),
              backgroundColor: DonyColors.success500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
            ),
          );
        } else if (state.submissionStatus == FormSubmissionStatus.error) {
          ErrorPresenter.show(
            context,
            state.errorMessage ?? 'Erreur lors de la création',
          );
        }
      },
      builder: (context, state) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SizedBox(
            height: sheetHeight.clamp(280.0, mq.size.height),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DonyRadius.sheet),
              ),
              child: ColoredBox(
                // Fond crème — identité Sahel Warmth
                color: DonyColors.sand100,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _Header(
                      currentStep: state.currentStep,
                      isEditing: state.isEditing,
                    ),
                    Expanded(
                      child: switch (state.currentStep) {
                        0 => Step1TrajetColis(key: _step1Key),
                        1 => Step2Details(key: _step2Key),
                        _ => Step3RecapBudget(key: _step3Key),
                      },
                    ),
                    _StickyCta(
                      currentStep: state.currentStep,
                      isSubmitting: state.submissionStatus ==
                          FormSubmissionStatus.submitting,
                      onPressed: () => _onCtaPressed(context, state),
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

  void _onCtaPressed(BuildContext context, PackageRequestFormState state) {
    switch (state.currentStep) {
      case 0:
        _step1Key.currentState?.submit();
        break;
      case 1:
        _step2Key.currentState?.submit();
        break;
      default:
        _step3Key.currentState?.submit();
        break;
    }
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.currentStep, this.isEditing = false});
  final int currentStep;
  final bool isEditing;

  String get _title => switch (currentStep) {
        0 => isEditing ? 'Modifier la demande' : 'Nouvelle demande',
        1 => 'Ton colis',
        _ => 'Dernière étape',
      };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: DonyColors.sand100,
        border: Border(
          bottom: BorderSide(color: DonyColors.neutral200),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: DonySpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DonyColors.neutral300,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
          ),
          // Titre + badge étape
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.sm,
              DonySpacing.sm,
              DonySpacing.base,
              DonySpacing.sm,
            ),
            child: Row(
              children: [
                Builder(builder: (ctx) {
                  final cs = Theme.of(ctx).colorScheme;
                  return IconButton(
                    tooltip: 'Retour',
                    onPressed: () {
                      if (currentStep > 0) {
                        context
                            .read<PackageRequestFormBloc>()
                            .add(const FormStepBack());
                      } else {
                        Navigator.of(context, rootNavigator: true).maybePop();
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
                  );
                }),
                Expanded(
                  child: Text(
                    _title,
                    style: tt.titleLarge?.copyWith(
                      color: DonyColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                // Badge étape
                Builder(builder: (ctx) {
                  final cs = Theme.of(ctx).colorScheme;
                  return Container(
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
                      '${currentStep + 1} / 3',
                      style: tt.labelSmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          WizardStepIndicator(currentStep: currentStep),
        ],
      ),
    );
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
          DonyButton(
            label: isSubmitting
                ? 'Publication…'
                : isFinalStep
                    ? 'Publier ma demande'
                    : 'Continuer',
            iconRightAsset: isFinalStep
                ? 'send'
                : 'arrow-right',
            onPressed: isSubmitting ? null : onPressed,
            isLoading: isSubmitting,
          ),
        ],
      ),
    );
  }
}

