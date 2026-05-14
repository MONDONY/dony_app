import 'package:dio/dio.dart' show Options;
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Retire le splash natif dès que Flutter a dessiné son premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _checkAndNavigate();
    });
  }

  Future<void> _checkAndNavigate() async {
    const maxAttempts = 3;
    const retryDelay = Duration(milliseconds: 1500);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) return;
      try {
        final response = await getIt<ApiClient>().dio.get<Map<String, dynamic>>(
              '/actuator/health',
              options: Options(extra: {'skipAuth': true}),
            );
        final status = response.data?['status'] as String? ?? '';
        if (!mounted) return;
        if (status == 'UP') {
          await _navigateNext();
          return;
        }
      } catch (_) {
        // tentative échouée — on retente silencieusement
      }

      // Pause avant la prochaine tentative (sauf sur la dernière)
      if (attempt < maxAttempts - 1) {
        await Future.delayed(retryDelay);
      }
    }

    // Toutes les tentatives épuisées
    if (mounted) setState(() => _hasError = true);
  }

  Future<void> _navigateNext() async {
    // First-launch check: show onboarding once
    final prefs = Hive.box('user_prefs');
    final onboardingDone = prefs.get('onboarding_done', defaultValue: false) as bool;
    if (!onboardingDone) {
      if (mounted) {
        context.go('/onboarding');
      }
      return;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) {
        context.go('/auth/phone');
      }
      return;
    }

    if (!mounted) {
      return;
    }
    final authBloc = context.read<AuthBloc>();
    authBloc.add(const AuthCheckRequested());

    final result = await authBloc.stream
        .firstWhere(
          (s) => s is AuthAuthenticated || s is AuthInitial || s is AuthError,
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => const AuthError(TimeoutException()),
        );

    if (!mounted) {
      return;
    }
    if (result is AuthAuthenticated) {
      context.go('/auth/local');
    } else if (result is AuthInitial) {
      context.go('/onboarding');
    } else {
      setState(() => _hasError = true);
    }
  }

  void _retry() {
    setState(() => _hasError = false);
    _checkAndNavigate();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final h = DonyLayout.hPadding(context);

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const DonyMascotteAnimated(
                    type: DonyMascotteType.joyeux,
                    size: DonyMascotteSize.xl,
                  ),
                  const SizedBox(height: DonySpacing.xl),
                  const DonyLogo(variant: DonyLogoVariant.onLight, fontSize: 104),
                  const SizedBox(height: DonySpacing.xxl),
                  Text(
                    'Livrez en confiance',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  Text(
                    'v1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (!_hasError)
              Positioned(
                bottom: 48 + bottom,
                left: 0,
                right: 0,
                child: _LoadingDots(),
              ),
            if (_hasError)
              Positioned(
                bottom: 40 + bottom,
                left: h,
                right: h,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            color: cs.onSurfaceVariant, size: 16),
                        const SizedBox(width: DonySpacing.sm),
                        Text(
                          'Impossible de se connecter',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: Icon(Icons.refresh_rounded,
                          color: cs.primary, size: 16),
                      label: const Text('Réessayer'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: cs.primary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DonyRadius.md),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.xl,
                            vertical: DonySpacing.md),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        )
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
              delay: Duration(milliseconds: i * 180),
            )
            .scaleXY(begin: 0.3, end: 1.0, duration: 500.ms, curve: Curves.easeInOut)
            .fadeIn(begin: 0.2, duration: 500.ms);
      }),
    );
  }
}
