import 'package:dio/dio.dart' show Options;
import 'package:dony/core/constants/app_assets.dart';
import 'package:dony/core/di/injection.dart';
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
    try {
      final response = await getIt<ApiClient>().dio.get<Map<String, dynamic>>(
            '/actuator/health',
            options: Options(extra: {'skipAuth': true}),
          );
      final status = response.data?['status'] as String? ?? '';
      if (!mounted) {
        return;
      }
      if (status == 'UP') {
        await _navigateNext();
      } else {
        setState(() => _hasError = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  Future<void> _navigateNext() async {
    // First-launch check: show onboarding once
    final prefs = Hive.box('user_prefs');
    final onboardingDone = prefs.get('onboarding_done', defaultValue: false) as bool;
    if (!onboardingDone) {
      await prefs.put('onboarding_done', true);
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

    final result = await authBloc.stream.firstWhere(
      (s) => s is AuthAuthenticated || s is AuthInitial || s is AuthError,
    );

    if (!mounted) {
      return;
    }
    if (result is AuthAuthenticated) {
      context.go('/auth/local');
    } else if (result is AuthInitial) {
      context.go('/auth/role');
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      body: Stack(
        children: [
          // Contenu statique — identique à l'image native splash_full.png
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Grand logo sans animation — même position que sur l'écran natif
                Image.asset(AppAssets.logoWhite, height: 160),
                const SizedBox(height: 28),
                const Text(
                  'Livrez en confiance',
                  style: TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 18,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: Color(0x5DFFFFFF),
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Points de chargement animés en bas
          if (!_hasError)
            Positioned(
              bottom: 64,
              left: 0,
              right: 0,
              child: _LoadingDots(),
            ),
          // Erreur réseau
          if (_hasError)
            Positioned(
              bottom: 48,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Impossible de se connecter',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                    label: const Text(
                      'Réessayer',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            ),
        ],
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Colors.white54,
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
