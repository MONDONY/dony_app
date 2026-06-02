import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Branche le tracking sur le cycle de vie d'authentification.
///
/// - Login  → [AnalyticsService.identify]
/// - Logout → [AnalyticsService.reset]
///
/// Le consentement est demandé une seule fois, pendant l'inscription,
/// via [AnalyticsConsentScreen] (après le PIN setup). Ce widget ne montre
/// plus aucune UI de consentement.
class AnalyticsConsentGate extends StatefulWidget {
  const AnalyticsConsentGate({required this.child, super.key});

  final Widget child;

  @override
  State<AnalyticsConsentGate> createState() => _AnalyticsConsentGateState();
}

class _AnalyticsConsentGateState extends State<AnalyticsConsentGate> {
  StreamSubscription<User?>? _authSub;

  AnalyticsService get _analytics => getIt<AnalyticsService>();

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);

    // authStateChanges() est un broadcast stream : si l'utilisateur est déjà
    // connecté au mount, le stream ne rejoue pas l'état courant.
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
    } else {
      unawaited(_analytics.reset());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
