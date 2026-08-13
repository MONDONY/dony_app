import 'dart:async';

import 'package:dony/app/router.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/gdpr_helper.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Branche le tracking sur le cycle de vie d'authentification et met à jour
/// le pays détecté par GPS à chaque connexion.
///
/// - Login  → [AnalyticsService.identify] + détection pays GPS (si permission)
///   + tranche le consentement analytics (cf. [GdprHelper.resolveConsentAction]) :
///   zone RGPD (ou pays indéterminé) → écran de consentement ; zone hors RGPD
///   → consentement accordé automatiquement, sans écran.
/// - Consentement accordé en cours de session (écran RGPD, sheet, réglages,
///   ou l'auto-octroi ci-dessus) → ré-identifie l'utilisateur courant. Sans
///   ça, `identify()` ne tirerait qu'au login Firebase (une fois par
///   lancement d'app) : un consentement donné après coup resterait rattaché
///   à un `distinct_id` anonyme jusqu'au prochain redémarrage.
/// - Logout → [AnalyticsService.reset]
class AnalyticsConsentGate extends StatefulWidget {
  const AnalyticsConsentGate({required this.child, super.key});

  final Widget child;

  @override
  State<AnalyticsConsentGate> createState() => _AnalyticsConsentGateState();
}

class _AnalyticsConsentGateState extends State<AnalyticsConsentGate> {
  StreamSubscription<User?>? _authSub;
  late final ValueListenable<Box> _consentListenable;

  AnalyticsService get _analytics => getIt<AnalyticsService>();

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);

    _consentListenable = getIt<HiveService>().userPrefs.listenable(
      keys: [HiveService.kAnalyticsConsent],
    );
    _consentListenable.addListener(_onConsentChanged);

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
    _consentListenable.removeListener(_onConsentChanged);
    super.dispose();
  }

  /// Ré-identifie l'utilisateur courant dès que le consentement passe à
  /// `true`, peu importe le chemin (écran RGPD, sheet, réglages, auto-octroi
  /// hors RGPD). Pas d'effet sur un octroi `false` (déconnexion du tracking,
  /// rien à identifier).
  void _onConsentChanged() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _analytics.isEnabled) {
      unawaited(_analytics.identify(user.uid));
    }
  }

  void _onAuthChanged(User? user) {
    if (user != null) {
      unawaited(_onLogin(user));
    } else {
      unawaited(_analytics.reset());
    }
  }

  /// Sur login : identifie l'utilisateur, réconcilie le consentement avec le
  /// backend (source de vérité), raffine le pays via GPS si possible, PUIS
  /// tranche le consentement. La sync doit précéder tout le reste : un
  /// utilisateur réinstallé ayant déjà consenti côté backend voit
  /// `hasAnswered` redevenir `true` et n'est donc pas redemandé.
  Future<void> _onLogin(User user) async {
    unawaited(_analytics.identify(user.uid));
    await _analytics.syncFromBackend();
    if (!mounted) return;

    final prefs = getIt<HiveService>().userPrefs;
    await _refineCountryFromGps(prefs);
    if (!mounted) return;

    final action = GdprHelper.resolveConsentAction(
      isConfigured: _analytics.isConfigured,
      hasAnswered: _analytics.hasAnswered,
      requiresConsent: GdprHelper.requiresConsent(prefs: prefs),
    );

    switch (action) {
      case AnalyticsConsentAction.askConsent:
        appRouter.go('/auth/analytics-consent');
      case AnalyticsConsentAction.autoGrantNonGdpr:
        await _analytics.setConsent(granted: true, source: 'auto_non_gdpr');
      case AnalyticsConsentAction.none:
        break;
    }
  }

  /// Tente de raffiner le pays de l'utilisateur via GPS (best-effort).
  ///
  /// Ne demande PAS la permission — utilise uniquement la permission déjà
  /// accordée par l'utilisateur (ex: lors du scan QR). Sans permission ou en
  /// cas d'échec, [GdprHelper.requiresConsent] retombe sur la locale device :
  /// la décision de consentement ne dépend donc jamais de la disponibilité du
  /// GPS.
  Future<void> _refineCountryFromGps(Box prefs) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      await GdprHelper.updateFromPosition(position, prefs);
    } catch (_) {
      // Non-fatal : la détection locale (device locale) reste active.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
