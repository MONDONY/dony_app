import 'dart:async';

import 'package:dony/core/storage/hive_service.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Version de la politique de confidentialité affichée à l'utilisateur au
/// moment où il donne (ou retire) son consentement analytics. Envoyée au
/// backend comme preuve légale (RGPD/CNIL) de ce qui a été présenté.
const kAnalyticsPolicyVersion = '1.0';

/// Persistance distante du consentement analytics (source de vérité backend).
///
/// L'implémentation par défaut ([NoopAnalyticsConsentRemote]) ne fait rien :
/// elle garde le service utilisable sans réseau (tests, builds sans backend).
/// En production on injecte `ApiAnalyticsConsentRemote` (cf.
/// `analytics_consent_remote.dart`).
abstract interface class AnalyticsConsentRemote {
  /// `null` = le backend n'a pas de réponse pour cet utilisateur.
  Future<bool?> fetch();

  /// Pousse la décision de l'utilisateur vers le backend (PUT). Non bloquant
  /// côté appelant (toujours `unawaited`).
  Future<void> push({
    required bool granted,
    required String policyVersion,
    required String source,
  });
}

/// Implémentation no-op : aucun appel réseau. Sert de défaut pour garder les
/// instanciations `AnalyticsService(hive)` existantes compilables.
class NoopAnalyticsConsentRemote implements AnalyticsConsentRemote {
  const NoopAnalyticsConsentRemote();

  @override
  Future<bool?> fetch() async => null;

  @override
  Future<void> push({
    required bool granted,
    required String policyVersion,
    required String source,
  }) async {}
}

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
    AnalyticsConsentRemote remote = const NoopAnalyticsConsentRemote(),
  })  : _backend = backend,
        _remote = remote;

  final HiveService _hive;
  final AnalyticsBackend _backend;
  final AnalyticsConsentRemote _remote;

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

  /// Pousse la décision vers le backend sans jamais lever : la persistance
  /// distante est best-effort (toujours `unawaited`). Un échec réseau ne doit
  /// ni bloquer l'UX/tracking, ni produire une erreur async non gérée.
  Future<void> _safePush(bool granted, String source) async {
    try {
      await _remote.push(
        granted: granted,
        policyVersion: kAnalyticsPolicyVersion,
        source: source,
      );
    } catch (_) {
      // Best-effort : le backend sera resynchronisé au prochain login.
    }
  }

  /// Enregistre la réponse de l'utilisateur et (dés)active le tracking.
  /// Révocable à tout moment (Réglages › Confidentialité).
  ///
  /// [source] identifie l'origine de la décision (`manual`, `auto_non_gdpr`,
  /// `settings`, `sync`) — stocké côté backend pour la preuve légale.
  /// La poussée vers le backend est `unawaited` : le réseau ne doit jamais
  /// bloquer l'UX ni le tracking.
  Future<void> setConsent({
    required bool granted,
    String source = 'manual',
  }) async {
    await _hive.userPrefs.put(HiveService.kAnalyticsConsent, granted);
    if (_configured) {
      await _applyConsent();
    }
    unawaited(_safePush(granted, source));
  }

  /// Réconcilie le consentement local (Hive) avec le backend (source de
  /// vérité) — à appeler au login. Permet à un utilisateur réinstallé ou
  /// multi-appareils de retrouver son choix sans être redemandé.
  ///
  /// - Backend a une réponse → elle prime : on aligne Hive (et PostHog si
  ///   déjà configuré). Une révocation faite ailleurs (`granted=false`)
  ///   désactive donc le tracking ici aussi.
  /// - Backend n'a rien mais on a un choix local → on le pousse (réinstall où
  ///   le PUT initial n'était jamais parti, ou offline).
  /// - Erreur réseau → on garde l'état local (no-op).
  Future<void> syncFromBackend() async {
    try {
      final backendGranted = await _remote.fetch();
      if (backendGranted != null) {
        if (consent != backendGranted) {
          await _hive.userPrefs
              .put(HiveService.kAnalyticsConsent, backendGranted);
        }
        if (_configured) await _applyConsent();
      } else if (hasAnswered) {
        unawaited(_safePush(consent!, 'sync'));
      }
    } catch (_) {
      // Réseau indisponible / backend en erreur → on conserve l'état local.
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
