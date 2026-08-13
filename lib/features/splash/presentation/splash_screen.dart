import 'dart:async';

import 'package:dio/dio.dart' show Options;
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
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
  bool _startupScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startupScheduled) {
      return;
    }
    _startupScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await precacheImage(
        const AssetImage('assets/splash/logo_name.png'),
        context,
      );
      if (!mounted) {
        return;
      }
      FlutterNativeSplash.remove();
      await _checkAndNavigate();
    });
  }

  Future<void> _checkAndNavigate() async {
    // 9 tentatives avec backoff croissant (600 ms → 3 s plafonné) : budget
    // total ~18 s d'attente entre tentatives (doublé depuis la version à 6
    // tentatives/~9 s, encore trop court pour certains cold starts réseau —
    // radio cellulaire pas encore réveillée après fermeture complète de
    // l'app, DNS/TLS à froid...). Acceptable sur cet écran puisqu'il porte
    // déjà une animation de chargement plutôt qu'un écran figé.
    const maxAttempts = 9;
    const baseDelay = Duration(milliseconds: 600);
    const maxDelay = Duration(milliseconds: 3000);

    Object? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) {
        return;
      }
      try {
        final response = await getIt<ApiClient>().dio.get<Map<String, dynamic>>(
          '/actuator/health',
          options: Options(
            // Le splash gère déjà son propre retry avec backoff ci-dessous —
            // sans ce flag, RetryOnTransientErrorInterceptor retente aussi en
            // interne (jusqu'à 3×), ce qui cumule les deux boucles sans que
            // l'une sache de l'autre et déséquilibre le budget de 6 tentatives.
            extra: {'skipAuth': true, 'skipTransientRetry': true},
          ),
        );
        final status = response.data?['status'] as String? ?? '';
        if (!mounted) {
          return;
        }
        if (status == 'UP') {
          await _navigateNext();
          return;
        }
      } catch (e) {
        // tentative échouée — on retente silencieusement
        lastError = e;
      }

      // Pause avant la prochaine tentative (sauf sur la dernière)
      if (attempt < maxAttempts - 1) {
        final delay = baseDelay * (attempt + 1);
        await Future.delayed(delay < maxDelay ? delay : maxDelay);
      }
    }

    // Toutes les tentatives épuisées — jusque-là totalement silencieux, on
    // n'avait donc aucune donnée pour diagnostiquer ce cas en prod.
    if (lastError != null) {
      unawaited(
        getIt<ErrorReportingService>().report(
          lastError,
          operation: 'splash.health_check',
          context: {'feature': 'splash'},
        ),
      );
    }
    if (mounted) {
      setState(() => _hasError = true);
    }
  }

  Future<void> _navigateNext() async {
    // 1. Session Firebase restaurée ? → on la vérifie AVANT toute autre chose.
    //    Si le compte existe en backend, on va directement au PIN : un
    //    utilisateur déjà connecté ne doit JAMAIS repasser par l'onboarding ni
    //    par l'OTP. (Le PIN seul suffit à déverrouiller la session persistée.)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
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
        // Le verrouillage est facultatif : on ne montre l'écran de code que si
        // l'utilisateur en a créé un. Sinon on entre directement, sans faire
        // clignoter un écran de saisie qui se refermerait aussitôt.
        final pinSet = await getIt<LocalAuthService>().isPinSet();
        if (!mounted) {
          return;
        }
        context.go(pinSet ? '/auth/local' : '/home');
        return;
      }
      if (result is AuthError) {
        setState(() => _hasError = true);
        return;
      }
      // AuthInitial : session Firebase OK mais pas (ou plus) inscrit en backend
      // → on poursuit vers onboarding/login ci-dessous.
    }

    // 2. Pas de session exploitable → onboarding (1ʳᵉ fois) puis choix du mode
    //    de connexion.
    final prefs = Hive.box('user_prefs');
    final onboardingDone =
        prefs.get('onboarding_done', defaultValue: false) as bool;
    if (!mounted) {
      return;
    }
    if (!onboardingDone) {
      context.go('/onboarding');
    } else {
      context.go('/auth/method');
    }
  }

  void _retry() {
    setState(() => _hasError = false);
    _checkAndNavigate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DonyColors.neutral0,
      body: SplashContent(hasError: _hasError, onRetry: _retry),
    );
  }
}

@visibleForTesting
class SplashContent extends StatelessWidget {
  const SplashContent({
    required this.hasError,
    this.onRetry = _noop,
    super.key,
  });

  final bool hasError;
  final VoidCallback onRetry;

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: DonyColors.neutral0,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoWidth = (constraints.maxWidth * 0.78).clamp(240.0, 560.0);
            final logoHeight = (constraints.maxHeight * 0.30).clamp(
              112.0,
              260.0,
            );

            final logo = ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: logoWidth,
                maxHeight: logoHeight,
              ),
              child: Image.asset(
                'assets/splash/logo_name.png',
                key: const Key('splash-brand-logo'),
                fit: BoxFit.contain,
                semanticLabel: 'Yadony',
              ),
            );

            final copy = Column(
              children: [
                Text(
                  'Livrez vos colis en confiance',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: DonyColors.textMuted,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  'v1.0.0',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: DonyColors.textSubtle,
                    letterSpacing: 0,
                  ),
                ),
              ],
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.xl,
                vertical: DonySpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - DonySpacing.huge).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (reduceMotion)
                      logo
                    else
                      logo
                          .animate()
                          .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
                          .slideY(
                            begin: 0.08,
                            end: 0,
                            duration: 280.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    const SizedBox(height: DonySpacing.xxl),
                    if (reduceMotion)
                      copy
                    else
                      copy.animate().fadeIn(
                        delay: 100.ms,
                        duration: 240.ms,
                        curve: Curves.easeOutCubic,
                      ),
                    const SizedBox(height: DonySpacing.xxl),
                    if (hasError)
                      _SplashError(
                        onRetry: onRetry,
                        disableAnimation: reduceMotion,
                      )
                    else
                      _LoadingDots(disableAnimation: reduceMotion),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SplashError extends StatelessWidget {
  const _SplashError({required this.onRetry, required this.disableAnimation});

  final VoidCallback onRetry;
  final bool disableAnimation;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DonyIcon('wifi-off', color: DonyColors.textMuted, size: 16),
            const SizedBox(width: DonySpacing.sm),
            Flexible(
              child: Text(
                'Impossible de se connecter',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: DonyColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.lg),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const DonyIcon(
            'refresh-cw',
            color: DonyColors.primary,
            size: 16,
          ),
          label: const Text('Réessayer'),
          style: OutlinedButton.styleFrom(
            foregroundColor: DonyColors.primary,
            minimumSize: const Size(0, kDonyMinTapTarget),
            side: const BorderSide(color: DonyColors.blue200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.xl,
              vertical: DonySpacing.md,
            ),
          ),
        ),
      ],
    );

    if (disableAnimation) {
      return content;
    }
    return content.animate().fadeIn(
      duration: 300.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.disableAnimation});

  final bool disableAnimation;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final dot = Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: DonyColors.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        );
        if (disableAnimation) {
          return dot;
        }
        return dot
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
              delay: Duration(milliseconds: i * 180),
            )
            .scaleXY(
              begin: 0.3,
              end: 1.0,
              duration: 500.ms,
              curve: Curves.easeInOut,
            )
            .fadeIn(begin: 0.2, duration: 500.ms);
      }),
    );
  }
}
