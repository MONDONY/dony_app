import 'dart:async';

import 'package:dony/app/router.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/analytics_consent_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Branche le tracking sur le cycle de vie d'authentification.
///
/// Utilise [FirebaseAuth.instance.authStateChanges()] pour éviter toute
/// dépendance au context/BlocProvider (AuthBloc est un factory GetIt).
///
/// Le sheet de consentement n'est montré qu'une fois l'utilisateur arrivé
/// sur `/home`, pour ne pas interférer avec les écrans de setup (PIN, KYC…).
class AnalyticsConsentGate extends StatefulWidget {
  const AnalyticsConsentGate({required this.child, super.key});

  final Widget child;

  @override
  State<AnalyticsConsentGate> createState() => _AnalyticsConsentGateState();
}

class _AnalyticsConsentGateState extends State<AnalyticsConsentGate> {
  StreamSubscription<User?>? _authSub;
  bool _prompted = false;
  bool _prompting = false;

  AnalyticsService get _analytics => getIt<AnalyticsService>();

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);

    // authStateChanges() est un broadcast stream : si l'utilisateur est déjà
    // connecté au mount, le stream ne rejoue pas l'état courant. On vérifie
    // currentUser directement après le premier frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _onAuthChanged(user);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _onAuthChanged(User? user) {
    if (user != null) {
      unawaited(_analytics.identify(user.uid));
      unawaited(_maybePrompt(user.uid));
    } else {
      unawaited(_analytics.reset());
    }
  }

  Future<void> _maybePrompt(String userId) async {
    if (_prompted || _prompting || !_analytics.isConfigured || _analytics.hasAnswered) {
      return;
    }
    _prompting = true;

    // 1. Attendre que le Navigator GoRouter soit prêt (max 2 s).
    BuildContext? navContext;
    for (var i = 0; i < 40; i++) {
      navContext = appRouter.routerDelegate.navigatorKey.currentContext;
      if (navContext != null) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (navContext == null) {
      _prompting = false;
      return;
    }

    // 2. Attendre que la navigation se stabilise sur /home (max 10 s).
    // Évite d'interrompre les écrans de setup post-login (PIN, KYC, onboarding).
    for (var i = 0; i < 100; i++) {
      final location = appRouter.routerDelegate.currentConfiguration.uri.path;
      if (location.startsWith('/home')) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Vérification finale : on est bien sur /home.
    final location = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (!location.startsWith('/home')) {
      _prompting = false;
      return;
    }

    _prompting = false;
    _prompted = true;
    final granted = await AnalyticsConsentSheet.show(navContext);
    if (granted) {
      await _analytics.identify(userId);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
