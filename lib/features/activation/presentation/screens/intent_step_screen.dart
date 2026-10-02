import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/intent_form.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Étape d'inscription « Votre projet », juste après le choix du pays.
const String intentStepRoute = '/auth/intent';

/// Où reprendre l'inscription après l'étape (et avec quel `extra`).
class IntentStepArgs {
  const IntentStepArgs({required this.next, this.nextExtra});

  final String next;
  final Object? nextExtra;
}

class IntentStepScreen extends StatelessWidget {
  const IntentStepScreen({
    super.key,
    required this.progress,
    required this.args,
  });

  final OnboardingProgress progress;
  final IntentStepArgs args;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final hPadding = DonyLayout.hPadding(context);
    return BlocListener<IntentCubit, IntentFormState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        // Une erreur n'empêche jamais de finir l'inscription : l'intention
        // sera redemandée sur l'accueil (comptes sans intention).
        if (state.status == IntentFormStatus.saved ||
            state.status == IntentFormStatus.error) {
          context.go(args.next, extra: args.nextExtra);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AuthFlowBackground(),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  hPadding,
                  DonySpacing.base,
                  hPadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthFlowHeader.gauge(
                      segments: progress.segments,
                      label: l.authStepIntent,
                    ),
                    const SizedBox(height: DonySpacing.lg),
                    Text(
                      l.intentTitle,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(l.intentSubtitle, style: text.bodyMedium),
                    const SizedBox(height: DonySpacing.lg),
                    const Expanded(
                      child: SingleChildScrollView(child: IntentForm()),
                    ),
                    BlocBuilder<IntentCubit, IntentFormState>(
                      builder: (context, state) => AuthFlowActions(
                        primary: DonyButton(
                          key: const Key('intent-continue'),
                          label: l.intentContinue,
                          isLoading: state.status == IntentFormStatus.saving,
                          onPressed: state.isValid
                              ? () => context.read<IntentCubit>().submit(
                                  IntentSource.signup,
                                )
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
