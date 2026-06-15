import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.becomeTravelerStarted,
        ),
      );
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
                                    context.read<AuthBloc>().add(
                                      const AuthCheckRequested(),
                                    );
                                  }
                                },
                              )
                              .animate()
                              .fadeIn(delay: 80.ms)
                              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                          const SizedBox(height: DonySpacing.md),
                          _StepCard(
                                stepNumber: 2,
                                title: 'Compte bancaire connecté',
                                subtitle:
                                    'Recevez vos paiements automatiquement après chaque livraison.',
                                status: _stripeStepStatus(stripeStatus),
                                ctaLabel:
                                    stripeStatus == 'REJECTED' ||
                                        stripeStatus == 'DISABLED'
                                    ? 'Contacter le support'
                                    : 'Connecter mon compte',
                                showCta: !stripeComplete,
                                onCta:
                                    stripeStatus == 'REJECTED' ||
                                        stripeStatus == 'DISABLED'
                                    ? () =>
                                          context.push('/profile/help/contact')
                                    : () async {
                                        await context.push(
                                          '/payments/onboarding',
                                        );
                                        if (context.mounted) {
                                          context.read<AuthBloc>().add(
                                            const AuthCheckRequested(),
                                          );
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
                                            .add(
                                              const TravelerUpgradeDeactivateRequested(),
                                            ),
                                  iconAsset: 'plane-landing',
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                            .add(
                                              const TravelerUpgradeActivateRequested(),
                                            ),
                                  iconAsset: 'plane-takeoff',
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
    return Container(
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: DonyIcon(
              'plane-takeoff',
              color: cs.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(height: DonySpacing.lg),
          Text(
            'Devenir voyageur',
            style: tt.displayLarge?.copyWith(
              height: 1.2,
              color: cs.onPrimary,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Transporte des colis, gagne de l\'argent. Tu gardes ton compte expéditeur.',
            style: tt.bodyLarge?.copyWith(
              color: cs.onPrimary.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.03, curve: Curves.easeOutCubic);
  }
}

// ── Step status enum ──────────────────────────────────────────────────────────

enum _StepStatus { todo, pending, done, rejected }

// ── Step card ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.ctaLabel,
    required this.showCta,
    required this.onCta,
  });

  final int stepNumber;
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

    final bool isDone = status == _StepStatus.done;

    final Color badgeColor;
    final Color badgeBg;
    final Widget statusChip;

    switch (status) {
      case _StepStatus.done:
        badgeColor = cs.success;
        badgeBg = cs.successLight;
        statusChip = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('check', color: cs.success, size: 13),
            const SizedBox(width: DonySpacing.xxs),
            Text(
              'Vérifié',
              style: tt.labelSmall?.copyWith(
                color: cs.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      case _StepStatus.pending:
        badgeColor = cs.warning;
        badgeBg = cs.warningLight;
        statusChip = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.warning,
              ),
            ),
            const SizedBox(width: DonySpacing.xxs),
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
        badgeColor = cs.error;
        badgeBg = cs.errorContainer.withValues(alpha: 0.3);
        statusChip = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('triangle-alert', color: cs.error, size: 13),
            const SizedBox(width: DonySpacing.xxs),
            Text(
              'Refusé',
              style: tt.labelSmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case _StepStatus.todo:
        badgeColor = cs.onSurfaceVariant;
        badgeBg = cs.surfaceContainerHighest;
        statusChip = Text(
          'À faire',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        );
    }

    return DonyCard(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Circular step badge ──────────────────────────────────
          _StepBadge(
            stepNumber: stepNumber,
            isDone: isDone,
            color: badgeColor,
            bg: badgeBg,
          ),
          const SizedBox(width: DonySpacing.md),
          // ── Content ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    // Status chip (top-right)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: DonySpacing.xxs + 1,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(DonyRadius.full),
                      ),
                      child: statusChip,
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
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
          ),
        ],
      ),
    );
  }
}

// ── Step badge (circular) ─────────────────────────────────────────────────────

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.stepNumber,
    required this.isDone,
    required this.color,
    required this.bg,
  });

  final int stepNumber;
  final bool isDone;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Center(
        child: isDone
            ? DonyIcon('check', color: color, size: 20)
            : Text(
                '$stepNumber',
                style: tt.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
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
      iconAsset: 'info',
      message: message,
    );
  }
}
