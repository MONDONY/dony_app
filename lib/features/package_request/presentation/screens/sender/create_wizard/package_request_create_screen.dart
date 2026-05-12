import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_2_details.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_step_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Wizard 3 étapes en bottom sheet glass pour publier une demande de colis.
///
/// API d'entrée :
/// ```dart
/// PackageRequestCreateWizard.show(context);
/// ```
///
/// Layout :
/// - Bottom sheet 92% hauteur écran, transparent (aurora visible derrière).
/// - Handle bar + AppBar in-sheet "Étape X / 3" + step indicator.
/// - Scrollable content (le step actuel) avec glass cards.
/// - **Sticky CTA en bas** ("Continuer" / "Publier") via stickyBottom (jamais
///   masqué par le scroll).
/// - Aurora peach en fond, glass cards par-dessus.
abstract final class PackageRequestCreateWizard {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (sheetContext) {
        return BlocProvider(
          create: (_) => getIt<PackageRequestFormBloc>(),
          child: const _WizardSheet(),
        );
      },
    );
  }
}

// ─── Internal · widget compatibility for the GoRouter route ────────────────
//
// `/package-requests/new` est encore référencée par d'anciens deep links et
// par le router actuel. Ce widget thin ouvre la bottom sheet dès le premier
// frame et se pop quand la sheet se ferme.
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
    // Shrink the sheet when keyboard is up so content stays accessible
    final sheetHeight = (mq.size.height * 0.92) - keyboardInset;

    return BlocConsumer<PackageRequestFormBloc, PackageRequestFormState>(
      listener: (context, state) {
        if (state.submissionStatus == FormSubmissionStatus.success &&
            state.createdRequest != null) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Demande publiée — les voyageurs sont notifiés'),
              backgroundColor: DonyColors.success,
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
        final cs = Theme.of(context).colorScheme;
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
                color: cs.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _Header(currentStep: state.currentStep),
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

class _Header extends StatelessWidget {
  const _Header({required this.currentStep});
  final int currentStep;

  String get _titleByStep => switch (currentStep) {
        0 => 'Nouvelle demande',
        1 => 'Ton colis',
        _ => 'Dernière étape',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: DonySpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DonyColors.textPrimary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
          ),
          // Title row : ← + title centered + "X/3" right
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.sm,
              DonySpacing.sm,
              DonySpacing.base,
              DonySpacing.md,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 18,
                    color: DonyColors.textPrimary,
                  ),
                  onPressed: () {
                    if (currentStep > 0) {
                      context
                          .read<PackageRequestFormBloc>()
                          .add(const FormStepBack());
                    } else {
                      Navigator.of(context, rootNavigator: true).maybePop();
                    }
                  },
                ),
                Expanded(
                  child: Text(
                    _titleByStep,
                    style: tt.titleLarge?.copyWith(
                      color: DonyColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: DonySpacing.xs),
                  child: Text(
                    '${currentStep + 1}/3',
                    style: tt.bodyMedium?.copyWith(
                      color: DonyColors.textSubtle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          WizardStepIndicator(currentStep: currentStep),
        ],
      ),
    );
  }
}

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
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
        boxShadow: [
          BoxShadow(
            color: DonyColors.ink800.withValues(alpha: 0.08),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            onPressed: isSubmitting ? null : onPressed,
            icon: isFinalStep
                ? Icons.send_rounded
                : Icons.arrow_forward_rounded,
            isLoading: isSubmitting,
          ),
        ],
      ),
    );
  }
}
