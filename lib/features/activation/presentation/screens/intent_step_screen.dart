import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/intent_form.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_signup_cubit.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_signup_section.dart';
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
      listener: (context, state) async {
        // Une erreur n'empêche jamais de finir l'inscription : l'intention
        // sera redemandée sur l'accueil (comptes sans intention).
        if (state.status == IntentFormStatus.saved) {
          // Les premiers pas, plus loin, s'afficheront déjà personnalisés.
          unawaited(getItSafe<ActivationCubit>()?.load() ?? Future.value());
        }
        if (state.status == IntentFormStatus.saved ||
            state.status == IntentFormStatus.error) {
          // La demande GP Pro ne bloque jamais l'inscription : le cubit avale
          // ses erreurs, on poursuit dans tous les cas.
          // Sans attendre : la navigation ne dépend pas du réseau. L'appel
          // repository et l'event analytics vont au bout même écran fermé
          // (seul l'emit final du cubit est protégé par isClosed).
          unawaited(
            context.read<GpProSignupCubit>().submitIfChecked(state.intent),
          );
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
                      child: SingleChildScrollView(
                        // GP Pro juste sous les cartes, avant les pays : un
                        // voyageur la voit sans défiler.
                        child: IntentForm(belowIntents: _GpProSlot()),
                      ),
                    ),
                    BlocBuilder<IntentCubit, IntentFormState>(
                      builder: (context, state) =>
                          BlocBuilder<GpProSignupCubit, GpProSignupState>(
                            // Pas de reconstruction à chaque frappe du nom.
                            buildWhen: (p, c) =>
                                p.isCompleteFor(state.intent) !=
                                c.isCompleteFor(state.intent),
                            builder: (context, gp) => AuthFlowActions(
                              primary: DonyButton(
                                key: const Key('intent-continue'),
                                label: l.intentContinue,
                                isLoading:
                                    state.status == IntentFormStatus.saving,
                                onPressed:
                                    state.isValid &&
                                        gp.isCompleteFor(state.intent)
                                    ? () => context.read<IntentCubit>().submit(
                                        IntentSource.signup,
                                      )
                                    : null,
                              ),
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

/// Section GP Pro de l'inscription, montrée pour « Voyageur » et « Les
/// deux ». Elle se déplie sous les cartes au lieu d'apparaître d'un bloc.
class _GpProSlot extends StatelessWidget {
  const _GpProSlot();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return BlocBuilder<IntentCubit, IntentFormState>(
      buildWhen: (p, c) => p.intent != c.intent,
      builder: (context, state) {
        final visible =
            state.intent == UserIntent.traveler ||
            state.intent == UserIntent.both;
        return AnimatedSize(
          duration: reduceMotion ? Duration.zero : DonyDuration.base,
          curve: DonyCurve.enter,
          alignment: Alignment.topCenter,
          child: visible
              ? const Padding(
                  padding: EdgeInsets.only(
                    top: DonySpacing.xs,
                    bottom: DonySpacing.sm,
                  ),
                  child: GpProSignupSection(),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}
