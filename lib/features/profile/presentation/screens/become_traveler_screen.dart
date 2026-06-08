import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
import 'package:dony/features/profile/bloc/traveler_upgrade_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BecomeATravelerScreen extends StatefulWidget {
  const BecomeATravelerScreen({super.key});

  @override
  State<BecomeATravelerScreen> createState() => _BecomeATravelerScreenState();
}

class _BecomeATravelerScreenState extends State<BecomeATravelerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(getIt<AnalyticsService>().logEvent(AnalyticsEvents.becomeTravelerStarted));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TravelerUpgradeBloc, TravelerUpgradeState>(
      listener: (context, state) {
        if (state is TravelerUpgradeSuccess) {
          context.read<AuthBloc>().add(AuthUserSynced(state.user));
          DonySnackbar.show(
            context,
            message: 'Bienvenue parmi les voyageurs dony 🎉',
            type: DonySnackbarType.success,
          );
          if (context.canPop()) context.pop();
        } else if (state is TravelerUpgradeDeactivated) {
          context.read<AuthBloc>().add(AuthUserSynced(state.user));
          DonySnackbar.show(
            context,
            message: 'Compte voyageur désactivé',
            type: DonySnackbarType.info,
          );
          if (context.canPop()) context.pop();
        } else if (state is TravelerUpgradeError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, upgradeState) {
        return BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (prev, curr) =>
              curr is AuthAuthenticated || curr is AuthProfileUpdated,
          builder: (context, authState) {
            UserModel? user;
            if (authState is AuthAuthenticated) {
              user = authState.user;
            }
            if (authState is AuthProfileUpdated) {
              user = authState.user;
            }

            final kycStatus = user?.kycStatus ?? 'NOT_STARTED';
            final stripeStatus = user?.stripeAccountStatus ?? 'NOT_CREATED';
            final kycVerified = kycStatus == 'VERIFIED';
            final stripeComplete = stripeStatus == 'ONBOARDING_COMPLETE';
            final canActivate = kycVerified && stripeComplete;
            final isActivating = upgradeState is TravelerUpgradeLoading;
            final isTraveler = user?.isTraveler ?? false;

            return Scaffold(
              appBar: const DonyAppBar(title: 'Devenir voyageur'),
              body: Builder(
                builder: (context) {
                  final h = DonyLayout.hPadding(context);
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      h,
                      DonySpacing.xl,
                      h,
                      DonySpacing.huge,
                    ),
                    child: DonyLayout.constrained(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _HeroSection(),
                          const SizedBox(height: DonySpacing.xxl),
                          _StepCard(
                            stepNumber: 1,
                            icon: Icons.badge_rounded,
                            title: 'Identité vérifiée',
                            subtitle:
                                "Pièce d'identité et liveness check via Stripe Identity.",
                            status: _kycStepStatus(kycStatus),
                            ctaLabel: kycStatus == 'REJECTED'
                                ? 'Réessayer la vérification'
                                : 'Vérifier mon identité',
                            showCta: !kycVerified && kycStatus != 'PENDING',
                            onCta: () async {
                              await KycOnboardingBottomSheet.show(context);
                              if (context.mounted) {
                                context
                                    .read<AuthBloc>()
                                    .add(const AuthCheckRequested());
                              }
                            },
                          )
                              .animate()
                              .fadeIn(delay: 80.ms)
                              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                          const SizedBox(height: DonySpacing.md),
                          _StepCard(
                            stepNumber: 2,
                            icon: Icons.account_balance_rounded,
                            title: 'Compte bancaire connecté',
                            subtitle:
                                'Recevez vos paiements automatiquement après chaque livraison.',
                            status: _stripeStepStatus(stripeStatus),
                            ctaLabel: stripeStatus == 'REJECTED' ||
                                    stripeStatus == 'DISABLED'
                                ? 'Contacter le support'
                                : 'Connecter mon compte',
                            showCta: !stripeComplete,
                            onCta: stripeStatus == 'REJECTED' ||
                                    stripeStatus == 'DISABLED'
                                ? () => context.push('/profile/help/contact')
                                : () async {
                                    await context.push('/payments/onboarding');
                                    if (context.mounted) {
                                      context
                                          .read<AuthBloc>()
                                          .add(const AuthCheckRequested());
                                    }
                                  },
                          )
                              .animate()
                              .fadeIn(delay: 140.ms)
                              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                          const SizedBox(height: DonySpacing.xxl),
                          if (isTraveler) ...[
                            DonyButton(
                              label: 'Désactiver mon compte voyageur',
                              isLoading: isActivating,
                              onPressed: isActivating
                                  ? null
                                  : () => context
                                      .read<TravelerUpgradeBloc>()
                                      .add(const TravelerUpgradeDeactivateRequested()),
                              icon: Icons.flight_land_rounded,
                              variant: DonyButtonVariant.ghost,
                            )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .scale(
                                  begin: const Offset(0.95, 0.95),
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: DonySpacing.md),
                            Text(
                              'Votre vérification KYC et votre compte bancaire resteront actifs pour une réactivation future.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 240.ms),
                          ] else if (canActivate) ...[
                            DonyButton(
                              label: 'Activer mon compte voyageur',
                              isLoading: isActivating,
                              onPressed: isActivating
                                  ? null
                                  : () => context
                                      .read<TravelerUpgradeBloc>()
                                      .add(const TravelerUpgradeActivateRequested()),
                              icon: Icons.flight_takeoff_rounded,
                            )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .scale(
                                  begin: const Offset(0.95, 0.95),
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: DonySpacing.md),
                            Text(
                              "En activant, vous acceptez les conditions d'utilisation dony pour les voyageurs.",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 240.ms),
                          ] else
                            _PendingHint(
                              kycStatus: kycStatus,
                              stripeStatus: stripeStatus,
                            ).animate().fadeIn(delay: 200.ms),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  _StepStatus _kycStepStatus(String kycStatus) {
    return switch (kycStatus) {
      'VERIFIED' => _StepStatus.done,
      'PENDING' => _StepStatus.pending,
      'REJECTED' => _StepStatus.rejected,
      _ => _StepStatus.todo,
    };
  }

  _StepStatus _stripeStepStatus(String stripeStatus) {
    return switch (stripeStatus) {
      'ONBOARDING_COMPLETE' => _StepStatus.done,
      'PENDING_ONBOARDING' => _StepStatus.pending,
      'REJECTED' || 'DISABLED' => _StepStatus.rejected,
      _ => _StepStatus.todo,
    };
  }
}

// ── Hero section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DonyIconContainer(
          icon: Icons.flight_takeoff_rounded,
          size: DonyIconContainerSize.xl,
          borderRadius: DonyRadius.xl,
          backgroundColor: cs.secondaryContainer,
          iconColor: cs.secondary,
        ),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Devenez voyageur\ndony',
          style: tt.displayLarge?.copyWith(height: 1.2),
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          "Transportez des colis vers l'Afrique et soyez payé automatiquement après chaque livraison confirmée.",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── Step status enum ──────────────────────────────────────────────────────────

enum _StepStatus { todo, pending, done, rejected }

// ── Step card ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.ctaLabel,
    required this.showCta,
    required this.onCta,
  });

  final int stepNumber;
  final IconData icon;
  final String title;
  final String subtitle;
  final _StepStatus status;
  final String ctaLabel;
  final bool showCta;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final Color stepColor;
    final Color stepBg;
    final Widget statusWidget;

    switch (status) {
      case _StepStatus.done:
        stepColor = cs.success;
        stepBg = cs.successLight;
        statusWidget =
            Icon(Icons.check_circle_rounded, color: cs.success, size: 20);
      case _StepStatus.pending:
        stepColor = cs.warning;
        stepBg = cs.warningLight;
        statusWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.warning,
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'En cours',
              style: tt.labelSmall?.copyWith(
                color: cs.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case _StepStatus.rejected:
        stepColor = cs.error;
        stepBg = cs.errorContainer.withValues(alpha: 0.3);
        statusWidget =
            Icon(Icons.warning_amber_rounded, color: cs.error, size: 20);
      case _StepStatus.todo:
        stepColor = cs.onSurfaceVariant;
        stepBg = cs.surfaceContainerHighest;
        statusWidget = Text(
          'À faire',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        );
    }

    return DonyCard(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIconContainer(
                icon: icon,
                borderRadius: DonyRadius.md,
                backgroundColor: stepBg,
                iconColor: stepColor,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Étape $stepNumber — $title',
                      style:
                          tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              statusWidget,
            ],
          ),
          if (showCta) ...[
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              label: ctaLabel,
              variant: DonyButtonVariant.secondary,
              fullWidth: false,
              onPressed: onCta,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Pending hint ──────────────────────────────────────────────────────────────

class _PendingHint extends StatelessWidget {
  const _PendingHint({required this.kycStatus, required this.stripeStatus});

  final String kycStatus;
  final String stripeStatus;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (kycStatus == 'PENDING') {
      message =
          "Vérification d'identité en cours — Stripe Identity vous contactera sous 24h. Revenez ici une fois vérifié.";
    } else if (kycStatus != 'VERIFIED') {
      message =
          'Complétez les étapes ci-dessus pour activer votre compte voyageur.';
    } else if (stripeStatus == 'PENDING_ONBOARDING') {
      message =
          "Finalisation de votre compte bancaire en cours. Revenez ici une fois l'onboarding Stripe terminé.";
    } else {
      message =
          'Complétez les étapes ci-dessus pour activer votre compte voyageur.';
    }

    return DonyStatusBanner(
      type: DonyStatusBannerType.info,
      icon: Icons.info_outline_rounded,
      message: message,
    );
  }
}
