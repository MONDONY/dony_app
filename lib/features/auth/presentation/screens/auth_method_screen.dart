import 'dart:async';
import 'dart:ui';

import 'package:dony/core/config/google_auth_flag.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/post_signup_route.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AuthMethodScreen extends StatelessWidget {
  const AuthMethodScreen({super.key});

  bool get _showAppleButton => defaultTargetPlatform == TargetPlatform.iOS;

  bool get _showGoogleButton => googleSignInAvailable;

  Future<void> _continueAfterNewAccount(
    BuildContext context,
    UserModel user,
  ) async {
    // Lus avant l'await : après, le contexte peut être démonté.
    final stripe = context.read<StripeAccountBloc>().state;
    final country = context.read<BusinessPrefsBloc>().state.country;

    final route = await resolvePostSignupRoute(
      analytics: getIt<AnalyticsService>(),
      user: user,
      stripe: stripe,
      countryFallback: country,
    );
    if (context.mounted) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthNewAccountAuthenticated) {
            unawaited(_continueAfterNewAccount(context, state.user));
          } else if (state is AuthAuthenticated) {
            context.go('/auth/local');
          } else if (state is AuthOAuthNewUser) {
            // OAuth user not yet registered → auto-register (backend forces SENDER)
            context.read<AuthBloc>().add(
              AuthRegisterWithEmailRequested(email: state.email),
            );
          } else if (state is AuthGuestSessionReady) {
            context.go('/home');
          } else if (state is AuthError) {
            ErrorPresenter.show(context, state.error);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _LoginBackground(),
            SafeArea(
              child: DonyLayout.constrained(
                context,
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    h,
                    DonySpacing.base,
                    h,
                    DonySpacing.xl + media.padding.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          media.size.height -
                          media.padding.top -
                          media.padding.bottom -
                          DonySpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _LoginTopBar(),
                        SizedBox(
                          height: (media.size.height * 0.24).clamp(
                            126.0,
                            220.0,
                          ),
                        ),
                        const _LoginIntro()
                            .animate()
                            .fadeIn(delay: 60.ms)
                            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                        const SizedBox(height: DonySpacing.lg),
                        _AuthActionsPanel(
                              showAppleButton: _showAppleButton,
                              showGoogleButton: _showGoogleButton,
                            )
                            .animate()
                            .fadeIn(delay: 120.ms)
                            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                        const SizedBox(height: DonySpacing.base),
                        const _CguFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/illustrations/auth-login-security.png',
          fit: BoxFit.cover,
          semanticLabel: context.l10n.authMethodIllustrationLabel,
          opacity: AlwaysStoppedAnimation(isLight ? 0.32 : 1),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: isLight
                ? Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.30)
                : null,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? [
                      cs.surface.withValues(alpha: 0.90),
                      cs.primaryContainer.withValues(alpha: 0.62),
                      cs.surface.withValues(alpha: 0.86),
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.98),
                    ]
                  : [
                      DonyColors.ink900.withValues(alpha: 0.36),
                      DonyColors.ink900.withValues(alpha: 0.10),
                      DonyColors.ink900.withValues(alpha: 0.62),
                      DonyColors.ink900.withValues(alpha: 0.94),
                    ],
              stops: const [0, 0.32, 0.58, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginTopBar extends StatelessWidget {
  const _LoginTopBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
              decoration: BoxDecoration(
                color: cs.surface.withValues(
                  alpha: cs.brightness == Brightness.light ? 0.92 : 0.82,
                ),
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(
                  color: cs.outline.withValues(
                    alpha: cs.brightness == Brightness.light ? 0.42 : 0.28,
                  ),
                ),
              ),
              child: const Center(child: DonyLogo(fontSize: 28)),
            ),
          ),
        ),
        const Spacer(),
        const _SecureBadge(),
      ],
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLight = cs.brightness == Brightness.light;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
          decoration: BoxDecoration(
            color: isLight
                ? cs.primaryContainer.withValues(alpha: 0.92)
                : DonyColors.ink900.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(DonyRadius.full),
            border: Border.all(
              color: isLight
                  ? cs.primary.withValues(alpha: 0.18)
                  : DonyColors.neutral0.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon('shield-check', size: 18, color: cs.success),
              const SizedBox(width: DonySpacing.xs),
              Text(
                context.l10n.authMethodSecureBadge,
                style: tt.labelLarge?.copyWith(
                  color: isLight ? cs.primary : DonyColors.neutral0,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLight = cs.brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.authMethodTitle,
          style: tt.displayLarge?.copyWith(
            color: isLight ? cs.onSurface : DonyColors.neutral0,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          context.l10n.authMethodSubtitle,
          style: tt.bodyLarge?.copyWith(
            color: isLight
                ? cs.onSurfaceVariant
                : DonyColors.neutral0.withValues(alpha: 0.84),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Méthode de connexion lancée depuis cet écran, pour savoir quel bouton
/// porte le spinner pendant que l'`AuthBloc` travaille.
enum _PendingAuth { apple, google, guest }

class _AuthActionsPanel extends StatefulWidget {
  const _AuthActionsPanel({
    required this.showAppleButton,
    required this.showGoogleButton,
  });

  final bool showAppleButton;
  final bool showGoogleButton;

  @override
  State<_AuthActionsPanel> createState() => _AuthActionsPanelState();
}

/// Pendant une connexion Apple, Google ou invitée, les boutons restaient
/// actifs et muets : aucun retour visuel entre le toucher et la réponse du
/// fournisseur. Les testeurs iOS tapaient alors à répétition (rage clicks
/// PostHog du 27/09). Le bouton touché affiche désormais un spinner et les
/// autres se désactivent tant que le bloc est occupé.
///
/// L'occupation ne se lit pas seulement sur `AuthLoading` : l'`AuthBloc` est
/// global et peut être en chargement pour une autre raison à l'arrivée sur
/// l'écran. On ne bloque que si l'utilisateur a lancé une méthode d'ici.
class _AuthActionsPanelState extends State<_AuthActionsPanel> {
  final _pending = ValueNotifier<_PendingAuth?>(null);

  @override
  void dispose() {
    _pending.dispose();
    super.dispose();
  }

  static bool _isBusy(AuthState state) =>
      state is AuthLoading || state is AuthOAuthNewUser;

  void _start(_PendingAuth method, AuthEvent event) {
    _pending.value = method;
    context.read<AuthBloc>().add(event);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, state) => !_isBusy(state),
      // Annulation (Google revient à `AuthInitial`), erreur ou succès : le
      // bouton touché n'a plus rien à attendre.
      listener: (_, _) => _pending.value = null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: isLight
                  ? cs.surface.withValues(alpha: 0.94)
                  : DonyColors.ink900.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(DonyRadius.sheet),
              border: Border.all(
                color: isLight
                    ? cs.outline.withValues(alpha: 0.42)
                    : DonyColors.neutral0.withValues(alpha: 0.18),
              ),
              boxShadow: DonyShadow.lg,
            ),
            child: ValueListenableBuilder<_PendingAuth?>(
              valueListenable: _pending,
              builder: (context, pending, _) {
                final authState = context.watch<AuthBloc>().state;
                final active = pending != null && _isBusy(authState)
                    ? pending
                    : null;
                final locked = active != null;
                return _buildActions(context, active: active, locked: locked);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context, {
    required _PendingAuth? active,
    required bool locked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: smsAuthEnabledListenable,
          builder: (_, phoneEnabled, _) {
            if (!phoneEnabled) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PhoneCta(
                  onTap: locked ? null : () => context.push('/auth/phone'),
                ),
                const SizedBox(height: DonySpacing.sm),
              ],
            );
          },
        ),
        if (widget.showAppleButton) ...[
          _SocialCta(
            iconAsset: 'apple',
            label: context.l10n.authMethodContinueWithApple,
            isLoading: active == _PendingAuth.apple,
            onTap: locked
                ? null
                : () => _start(
                    _PendingAuth.apple,
                    const AuthAppleSignInRequested(),
                  ),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        if (widget.showGoogleButton) ...[
          _GoogleCta(
            isLoading: active == _PendingAuth.google,
            onTap: locked
                ? null
                : () => _start(
                    _PendingAuth.google,
                    const AuthGoogleSignInRequested(),
                  ),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        _SocialCta(
          iconAsset: 'mail',
          label: context.l10n.authMethodContinueWithEmail,
          onTap: locked ? null : () => context.push('/auth/email'),
        ),
        const SizedBox(height: DonySpacing.md),
        const _OrDivider(),
        const SizedBox(height: DonySpacing.md),
        _GuestCta(
          isLoading: active == _PendingAuth.guest,
          onTap: locked
              ? null
              : () => _start(
                  _PendingAuth.guest,
                  const AuthGuestSessionRequested(),
                ),
        ),
      ],
    );
  }
}

/// Spinner des boutons contour pendant la connexion, à la taille de l'icône
/// qu'il remplace pour que le bouton ne bouge pas.
class _CtaSpinner extends StatelessWidget {
  const _CtaSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _PhoneCta extends StatelessWidget {
  const _PhoneCta({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DonyButton(
        label: context.l10n.authMethodContinueWithPhone,
        onPressed: onTap,
      ),
    );
  }
}

class _SocialCta extends StatelessWidget {
  const _SocialCta({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });
  final String iconAsset;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        // Désactivé mais pas grisé pendant son propre chargement : le
        // spinner doit rester lisible.
        onPressed: isLoading ? () {} : onTap,
        icon: isLoading
            ? const _CtaSpinner()
            : DonyIcon(iconAsset, size: 20, color: cs.onSurface),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline.withValues(alpha: 0.72)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
        ),
      ),
    );
  }
}

class _GoogleCta extends StatelessWidget {
  const _GoogleCta({required this.onTap, this.isLoading = false});
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? () {} : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline.withValues(alpha: 0.72)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) const _CtaSpinner() else const _GoogleLogo(),
            const SizedBox(width: DonySpacing.sm),
            Text(context.l10n.authMethodContinueWithGoogle),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final sectors = [
      (0.0, 0.5236, const Color(0xFF4285F4)), // blue
      (0.5236, 1.0472, const Color(0xFFEA4335)), // red top-right
      (1.0472, 2.6180, const Color(0xFFFBBC05)), // yellow
      (2.6180, 3.6652, const Color(0xFF34A853)), // green
      (3.6652, 6.2832, const Color(0xFF4285F4)), // blue (remainder)
    ];

    for (final (start, end, color) in sectors) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(cx, cy)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          start,
          end - start,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }

    // White inner circle
    canvas.drawCircle(Offset(cx, cy), r * 0.6, Paint()..color = Colors.white);

    // Blue right notch (Google "G" opening)
    final notchPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.12, r * 0.95, r * 0.24),
      notchPaint,
    );
    canvas.drawCircle(Offset(cx + r * 0.95, cy), r * 0.12, notchPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Divider(color: cs.outline.withValues(alpha: 0.52), height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
          child: Text(
            context.l10n.authMethodOr,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: cs.outline.withValues(alpha: 0.52), height: 1),
        ),
      ],
    );
  }
}

class _GuestCta extends StatelessWidget {
  const _GuestCta({required this.onTap, this.isLoading = false});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: context.l10n.authMethodGuestSemantics,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(
            alpha: cs.brightness == Brightness.light ? 0.62 : 0.10,
          ),
          borderRadius: BorderRadius.circular(DonyRadius.xl),
          border: Border.all(
            color: cs.primary.withValues(
              alpha: cs.brightness == Brightness.light ? 0.18 : 0.28,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyButton(
              label: context.l10n.authMethodBrowseWithoutAccount,
              iconAsset: 'search',
              variant: DonyButtonVariant.secondary,
              isLoading: isLoading,
              onPressed: onTap,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              context.l10n.authMethodGuestNotice,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mention légale sous les boutons de connexion.
///
/// Les deux libellés étaient bleus et soulignés mais ne portaient aucun
/// `recognizer` : ils avaient l'apparence d'un lien sans en être un. On
/// demandait donc d'accepter des documents qu'aucun geste ne permettait
/// d'ouvrir. Les relecteurs Apple et Google les ouvrent depuis cet écran,
/// avant toute création de compte, d'où la route publique `/legal/…`.
class _CguFooter extends StatefulWidget {
  const _CguFooter();

  @override
  State<_CguFooter> createState() => _CguFooterState();
}

class _CguFooterState extends State<_CguFooter> {
  /// Un `TapGestureRecognizer` se libère à la main : construit dans `build()`,
  /// il fuirait à chaque reconstruction de l'écran.
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => unawaited(context.push('/legal/terms'));
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => unawaited(context.push('/legal/privacy'));

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final linkStyle = tt.bodySmall?.copyWith(
      color: cs.primary,
      decoration: TextDecoration.underline,
      decorationColor: cs.primary,
    );
    final l10n = context.l10n;
    return Text.rich(
      TextSpan(
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
        children: [
          TextSpan(text: l10n.authLegalPrefix),
          TextSpan(
            text: l10n.authLegalTermsLink,
            style: linkStyle,
            recognizer: _termsTap,
          ),
          TextSpan(text: l10n.authLegalMiddle),
          TextSpan(
            text: l10n.authLegalPrivacyLink,
            style: linkStyle,
            recognizer: _privacyTap,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
