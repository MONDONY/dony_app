import 'package:dony/features/auth/presentation/screens/local_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:dony/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:dony/features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:dony/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:dony/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [SentryNavigatorObserver()],
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) => const PhoneAuthScreen(),
    ),
    GoRoute(
      path: '/auth/otp',
      builder: (context, state) => const OtpVerificationScreen(),
    ),
    GoRoute(
      path: '/auth/role',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/auth/pin-setup',
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: '/auth/local',
      builder: (context, state) => const LocalAuthScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const _PlaceholderScreen(title: 'Accueil'),
    ),
    GoRoute(
      path: '/kyc',
      builder: (context, state) => const _PlaceholderScreen(title: 'Vérification KYC'),
    ),
    GoRoute(
      path: '/announcements',
      builder: (context, state) => const _PlaceholderScreen(title: 'Annonces'),
    ),
    GoRoute(
      path: '/announcements/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return _PlaceholderScreen(title: 'Annonce $id');
      },
    ),
    GoRoute(
      path: '/tracking/scan',
      builder: (context, state) => const _PlaceholderScreen(title: 'Scanner QR'),
    ),
    GoRoute(
      path: '/payment/confirm',
      builder: (context, state) => const _PlaceholderScreen(title: 'Confirmer paiement'),
    ),
    GoRoute(
      path: '/disputes',
      builder: (context, state) => const _PlaceholderScreen(title: 'Litiges'),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const _PlaceholderScreen(title: 'Admin'),
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(title)),
      );
}
