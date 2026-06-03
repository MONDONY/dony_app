import 'dart:async';

import 'package:dony/app/router.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/gdpr_helper.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

/// Branche le tracking sur le cycle de vie d'authentification et met à jour
/// le pays détecté par GPS à chaque connexion.
///
/// - Login  → [AnalyticsService.identify] + détection pays GPS (si permission)
/// - Logout → [AnalyticsService.reset]
///
/// Si le GPS révèle que l'utilisateur est dans un pays RGPD et que le
/// consentement n'a pas encore été recueilli, redirige vers l'écran de
/// consentement analytics.
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
      unawaited(_updateCountryFromGps());
    } else {
      unawaited(_analytics.reset());
    }
  }

  /// Tente de raffiner le pays de l'utilisateur via GPS.
  ///
  /// Ne demande PAS la permission — utilise uniquement la permission déjà
  /// accordée par l'utilisateur (ex: lors du scan QR).
  /// Si le pays détecté est RGPD et que le consentement n'a pas été
  /// recueilli, redirige vers l'écran de consentement.
  Future<void> _updateCountryFromGps() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      final prefs = getIt<HiveService>().userPrefs;
      await GdprHelper.updateFromPosition(position, prefs);

      if (_analytics.isConfigured &&
          !_analytics.hasAnswered &&
          GdprHelper.requiresConsent(prefs: prefs)) {
        appRouter.go('/auth/analytics-consent');
      }
    } catch (_) {
      // Non-fatal : la détection locale (device locale) reste active.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
