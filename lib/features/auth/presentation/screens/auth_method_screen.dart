import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AuthMethodScreen extends StatelessWidget {
  const AuthMethodScreen({super.key});

  bool get _showAppleButton => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/auth/local');
          } else if (state is AuthOAuthNewUser) {
            // OAuth user not yet registered → auto-register (backend forces SENDER)
            context.read<AuthBloc>().add(
              AuthRegisterWithEmailRequested(email: state.email),
            );
          } else if (state is AuthError) {
            DonySnackbar.show(
              context,
              message: state.error.message,
              type: DonySnackbarType.error,
            );
          }
        },
        child: SafeArea(
          child: DonyLayout.constrained(
            context,
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                h,
                DonySpacing.xxl,
                h,
                DonySpacing.xl + bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: DonyMascotteAnimated(type: DonyMascotteType.joyeux),
                  ),
                  const SizedBox(height: DonySpacing.md),
                  Center(child: _SecureBadge()),
                  const SizedBox(height: DonySpacing.xl),
                  Text(
                        'Connecte-toi',
                        style: tt.displayLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                        textAlign: TextAlign.center,
                      )
                      .animate()
                      .fadeIn(delay: 60.ms)
                      .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                  const SizedBox(height: DonySpacing.sm),
                  Text(
                    'Choisis le mode que tu préfères.\nNous protégeons toutes tes données.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: DonySpacing.xxl),
                  ValueListenableBuilder<bool>(
                    valueListenable: smsAuthEnabledListenable,
                    builder: (_, phoneEnabled, _) {
                      if (!phoneEnabled) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PhoneCta(onTap: () => context.push('/auth/phone'))
                              .animate()
                              .fadeIn(delay: 140.ms)
                              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                          const SizedBox(height: DonySpacing.md),
                          _OrDivider(),
                          const SizedBox(height: DonySpacing.md),
                        ],
                      );
                    },
                  ),
                  if (_showAppleButton) ...[
                    _SocialCta(
                          iconAsset: 'apple',
                          iconColor: cs.onSurface,
                          label: 'Continuer avec Apple',
                          onTap: () => context.read<AuthBloc>().add(
                            const AuthAppleSignInRequested(),
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 180.ms)
                        .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                    const SizedBox(height: DonySpacing.sm),
                  ],
                  _GoogleCta(
                        onTap: () => context.read<AuthBloc>().add(
                          const AuthGoogleSignInRequested(),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 220.ms)
                      .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                  const SizedBox(height: DonySpacing.sm),
                  _SocialCta(
                        iconAsset: 'mail',
                        iconColor: cs.onSurfaceVariant,
                        label: 'Continuer avec mon email',
                        onTap: () => context.push('/auth/email'),
                      )
                      .animate()
                      .fadeIn(delay: 260.ms)
                      .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                  const SizedBox(height: DonySpacing.xl),
                  _CguFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecureBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        '🔐  Authentification chiffrée',
        style: tt.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PhoneCta extends StatelessWidget {
  const _PhoneCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DonyButton(
        label: 'Continuer avec mon téléphone',
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
    this.iconColor,
  });
  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: DonyIcon(iconAsset, size: 20, color: iconColor ?? cs.onSurface),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
        ),
      ),
    );
  }
}

class _GoogleCta extends StatelessWidget {
  const _GoogleCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoogleLogo(),
            SizedBox(width: DonySpacing.sm),
            Text('Continuer avec Google'),
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
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outline, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
          child: Text(
            'OU',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: Divider(color: cs.outline, height: 1)),
      ],
    );
  }
}

class _CguFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
        children: [
          const TextSpan(text: 'En continuant tu acceptes nos '),
          TextSpan(
            text: 'CGU',
            style: tt.bodySmall?.copyWith(
              color: cs.primary,
              decoration: TextDecoration.underline,
              decorationColor: cs.primary,
            ),
          ),
          const TextSpan(text: ' et notre '),
          TextSpan(
            text: 'politique de confidentialité',
            style: tt.bodySmall?.copyWith(
              color: cs.primary,
              decoration: TextDecoration.underline,
              decorationColor: cs.primary,
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
