import 'package:dony/core/storage/hive_service.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Abstraction minimale du backend analytics.
///
/// Permet d'injecter PostHog en prod et un mock dans les tests sans dépendre
/// du SDK natif (qui n'est pas disponible dans l'environnement de test).
abstract interface class AnalyticsBackend {
  Future<void> capture(String event, Map<String, Object>? properties);
  Future<void> screen(String name, Map<String, Object>? properties);
  Future<void> identify(String userId, Map<String, Object>? properties);
  Future<void> reset();
  Future<void> optIn();
  Future<void> optOut();
}

/// Implémentation PostHog par défaut.
class PosthogBackend implements AnalyticsBackend {
  const PosthogBackend();

  @override
  Future<void> capture(String event, Map<String, Object>? properties) =>
      Posthog().capture(eventName: event, properties: properties);

  @override
  Future<void> screen(String name, Map<String, Object>? properties) =>
      Posthog().screen(screenName: name, properties: properties);

  @override
  Future<void> identify(String userId, Map<String, Object>? properties) =>
      Posthog().identify(userId: userId, userProperties: properties);

  @override
  Future<void> reset() => Posthog().reset();

  @override
  Future<void> optIn() => Posthog().enable();

  @override
  Future<void> optOut() => Posthog().disable();
}

/// Service central de tracking produit (PostHog) : events, écrans, identité.
///
/// **Consentement RGPD opt-in strict** : aucun event ni session replay n'est
/// envoyé tant que l'utilisateur n'a pas explicitement accepté. La source de
/// vérité du consentement est Hive ([HiveService.kAnalyticsConsent]) ; on la
/// réapplique à PostHog au démarrage via [onConfigured] pour éviter toute
/// dérive avec l'état opt-out persistant côté natif.
class AnalyticsService {
  AnalyticsService(
    this._hive, {
    AnalyticsBackend backend = const PosthogBackend(),
  }) : _backend = backend;

  final HiveService _hive;
  final AnalyticsBackend _backend;

  bool _configured = false;

  /// `true` une fois `Posthog().setup()` appelé avec succès (clé présente).
  /// Quand `false` (ex: build sans `POSTHOG_API_KEY`, tests), tout est no-op.
  bool get isConfigured => _configured;

  /// `null` = jamais demandé · `true` = accepté · `false` = refusé.
  bool? get consent {
    final value = _hive.userPrefs.get(HiveService.kAnalyticsConsent);
    return value is bool ? value : null;
  }

  /// L'utilisateur a-t-il déjà répondu à la demande de consentement ?
  bool get hasAnswered => consent != null;

  /// Le tracking est-il réellement actif (configuré ET consenti) ?
  bool get isEnabled => _configured && consent == true;

  /// À appeler une seule fois, après `Posthog().setup()`, pour activer le
  /// service et aligner PostHog sur le consentement déjà stocké.
  Future<void> onConfigured() async {
    _configured = true;
    await _applyConsent();
  }

  Future<void> _applyConsent() =>
      consent == true ? _backend.optIn() : _backend.optOut();

  /// Enregistre la réponse de l'utilisateur et (dés)active le tracking.
  /// Révocable à tout moment (Réglages › Confidentialité).
  Future<void> setConsent({required bool granted}) async {
    await _hive.userPrefs.put(HiveService.kAnalyticsConsent, granted);
    if (_configured) {
      await _applyConsent();
    }
  }

  /// Envoie un event métier (ex: `bid_accepted`, `package_request_created`).
  /// Ne jamais y mettre de PII (numéro, email, valeur de colis exacte).
  Future<void> logEvent(String name, {Map<String, Object>? properties}) async {
    if (!isEnabled) return;
    await _backend.capture(name, properties);
  }

  /// Marque une vue d'écran manuellement (l'auto-capture passe par
  /// `PosthogObserver` sur le GoRouter).
  Future<void> logScreen(String name, {Map<String, Object>? properties}) async {
    if (!isEnabled) return;
    await _backend.screen(name, properties);
  }

  /// Lie les events à l'utilisateur connecté. On utilise l'UID backend comme
  /// `distinctId` — jamais l'email ou le téléphone (PII).
  Future<void> identify(String userId,
      {Map<String, Object>? properties}) async {
    if (!isEnabled) return;
    await _backend.identify(userId, properties);
  }

  /// À la déconnexion : dissocie la session courante de l'utilisateur.
  Future<void> reset() async {
    if (_configured) {
      await _backend.reset();
    }
  }
}
