import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Progression de la configuration du **compte** — la même jauge que le
/// parcours d'inscription, vue depuis le profil.
///
/// La bannière « Profil incomplet » juste en dessous ne parle que des champs
/// de profil (photo, prénom, ville…) : elle ne dit rien de la vérification
/// d'identité (Stripe Identity) ni de l'activation des paiements (Stripe
/// Connect). Cette carte-ci porte exactement ce reste-là : les étapes du
/// parcours dont le fait serveur manque encore.
///
/// Ici la jauge lit les **faits accomplis** (une étape passée reste vide),
/// pas la position dans un parcours : la question du profil est « qu'est-ce
/// qui manque à ce compte », pas « où en suis-je ». C'est le repli naturel de
/// [OnboardingProgress.segments] quand ni `current` ni `reachedPast` ne sont
/// posés.
///
/// Le CTA reprend le parcours là où il s'est arrêté :
/// [OnboardingProgress.next] respecte le verrou identité → paiements, donc la
/// carte ne peut jamais conduire à un refus Stripe (422 `kyc-required`).
class AccountSetupCard extends StatelessWidget {
  const AccountSetupCard({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    // Reconstruit quand le statut Connect change (webhook relu au retour de
    // l'onboarding Stripe) : la carte doit disparaître d'elle-même à 5/5.
    return BlocBuilder<StripeAccountBloc, StripeAccountState>(
      builder: (context, stripe) {
        final analytics = getIt<AnalyticsService>();
        final progress = onboardingProgress(
          user: user,
          stripe: stripe,
          analyticsAnswered: !analytics.isConfigured || analytics.hasAnswered,
          countryFallback: context.read<BusinessPrefsBloc>().state.country,
        );

        final next = progress.next;
        if (next == null) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.lg),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
              ),
              child: InkWell(
                onTap: () => context.go(next.onboardingRoute),
                borderRadius: BorderRadius.circular(DonyRadius.card),
                child: Padding(
                  padding: const EdgeInsets.all(DonySpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(DonySpacing.sm),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                DonyRadius.md,
                              ),
                            ),
                            child: DonyIcon(
                              'shield-check',
                              color: cs.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Finalisez votre compte',
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                ),
                                Text(
                                  'Prochaine étape : ${next.displayLabel}',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DonyIcon(
                            'chevron-right',
                            color: cs.onSurfaceVariant,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: DonySpacing.md),
                      DonyOnboardingGauge(
                        segments: progress.segments,
                        label: next.displayLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
