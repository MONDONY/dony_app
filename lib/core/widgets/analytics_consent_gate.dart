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
/// - Session invitée (Firebase anonyme, "Parcourir sans compte") → AUCUN des
///   comportements ci-dessus. Un visiteur n'a pas de ligne côté backend
///   (`/auth/me/analytics-consent` répondrait 404) et son UID Firebase
///   anonyme ne doit jamais devenir un `distinct_id` PostHog : l'outil gère
///   déjà son propre identifiant anonyme, l'identifier créerait un
///   utilisateur identifié fantôme. Le consentement reste donc à sa valeur
///   par défaut (non répondu) tant que la session est anonyme.
class AnalyticsConsentGate extends StatefulWidget {
  const AnalyticsConsentGate({
    required this.child,
    this.firebaseAuth,
    this.navigate,
    super.key,
  });

  final Widget child;

  /// Overridable en test uniquement. En production, reste `null` et retombe
  /// sur [FirebaseAuth.instance] (même pattern que `AuthBloc`/
  /// `FirebaseSessionProbe`).
  final FirebaseAuth? firebaseAuth;

  /// Overridable en test uniquement. En production, reste `null` et retombe
  /// sur `appRouter.go` (le routeur global de l'app, `lib/app/router.dart`).
  /// Permet de verrouiller par un test direct qu'une session invitée ne
  /// déclenche JAMAIS de navigation vers l'entonnoir de consentement/
  /// inscription — le vrai risque produit de cette classe.
  final void Function(String location)? navigate;

  @override
  State<AnalyticsConsentGate> createState() => _AnalyticsConsentGateState();
}

class _AnalyticsConsentGateState extends State<AnalyticsConsentGate> {
  StreamSubscription<User?>? _authSub;
  late final ValueListenable<Box> _consentListenable;

  FirebaseAuth get _firebaseAuth =>
      widget.firebaseAuth ?? FirebaseAuth.instance;
  AnalyticsService get _analytics => getIt<AnalyticsService>();
  void Function(String location) get _navigate =>
      widget.navigate ?? appRouter.go;

  @override
  void initState() {
    super.initState();
    _authSub = _firebaseAuth.authStateChanges().listen(_onAuthChanged);

    _consentListenable = getIt<HiveService>().userPrefs.listenable(
      keys: [HiveService.kAnalyticsConsent],
    );
    _consentListenable.addListener(_onConsentChanged);

    // authStateChanges() est un broadcast stream : si l'utilisateur est déjà
    // connecté au mount, le stream ne rejoue pas l'état courant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = _firebaseAuth.currentUser;
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
  ///
  /// `!user.isAnonymous` : un visiteur ne doit jamais être identifié avec son
  /// UID Firebase anonyme, même si son consentement venait à changer par un
  /// autre chemin que [_onLogin] (qui ne le laisse de toute façon jamais
  /// passer).
  void _onConsentChanged() {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.isAnonymous && _analytics.isEnabled) {
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
    if (user.isAnonymous) {
      // Session invitée ("Parcourir sans compte") : ni identify() (UID
      // Firebase anonyme → utilisateur identifié fantôme dans PostHog, qui a
      // déjà son propre identifiant anonyme), ni syncFromBackend() (appelle
      // `/auth/me/analytics-consent`, un visiteur n'a pas de ligne backend et
      // recevrait un 404). Le consentement reste à sa valeur par défaut (non
      // répondu) : `AnalyticsService.isEnabled` reste `false` tant que rien
      // n'a été configuré/répondu, donc aucun tracking nominatif ici. Un vrai
      // login ultérieur (inscription) repasse par ce handler avec
      // `isAnonymous == false` et retrouve le comportement normal.
      return;
    }
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
        _navigate('/auth/analytics-consent');
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
