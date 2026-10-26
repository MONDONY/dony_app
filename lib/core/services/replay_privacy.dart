import 'dart:async';

import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Écrans (préfixes de chemin) qui ne sont **jamais** enregistrés dans le
/// replay de session : l'enregistrement est mis en pause tant que l'un d'eux
/// est affiché.
///
/// Les textes sont visibles dans le replay ; ces écrans affichent ou
/// collectent des données personnelles (identité, coordonnées, paiement,
/// messages, destinataire, codes de remise). Ajouter ici tout nouvel écran de
/// ce type.
const kReplaySensitivePathPrefixes = <String>[
  // Connexion : numéro, code reçu, e-mail, nom.
  '/auth/phone',
  '/auth/otp',
  '/auth/email',
  '/auth/email-otp',
  '/auth/personal-info',
  '/auth/referral-code',
  '/auth/local',
  // Identité et paiement.
  '/kyc',
  '/payments',
  '/payment',
  '/stripe',
  '/connect',
  // Messages, assistant, appels, litiges.
  '/conversations',
  '/messages',
  '/chat',
  '/support',
  '/assistant',
  '/calls',
  '/disputes',
  '/cancellations',
  // Colis en cours : noms, coordonnées du destinataire, montants, codes.
  '/colis',
  '/receptions',
  '/negotiations',
  '/recipient-invitations',
  '/tracking/validate',
  '/tracking/confirm',
  '/tracking/scan',
  // Compte et réglages : coordonnées, adresses, sécurité.
  '/profile/edit',
  '/profile/addresses',
  '/profile/recipients',
  '/profile/subscriptions',
  '/profile/upgrade-to-pro',
  '/settings',
  '/account',
];

/// Vrai si l'écran à [path] ne doit pas être enregistré.
///
/// Le détail d'un colis (`/bids/<id>…`) est sensible ; la création d'une
/// offre (`/bids/new`) ne l'est pas, ses champs étant masqués un à un. Le
/// profil (`/profile`) l'est aussi : nom, téléphone, e-mail et solde.
bool isReplaySensitivePath(String path) {
  if (path == '/profile') return true;
  if (path.startsWith('/bids/') && path != '/bids/new') return true;
  for (final prefix in kReplaySensitivePathPrefixes) {
    if (path == prefix || path.startsWith('$prefix/')) return true;
  }
  return false;
}

/// Pilote l'enregistrement du replay (mockable dans les tests).
abstract class ReplayRecordingControl {
  Future<void> stop();
  Future<void> resume();
}

class PosthogReplayRecordingControl implements ReplayRecordingControl {
  const PosthogReplayRecordingControl();

  @override
  Future<void> stop() => Posthog().stopSessionRecording();

  @override
  Future<void> resume() => Posthog().startSessionRecording();
}

/// Met le replay en pause sur les écrans sensibles et le reprend ensuite.
///
/// Ne reprend jamais sans consentement : un refus d'analytics garde le replay
/// éteint quel que soit l'écran.
class ReplayPrivacyObserver extends NavigatorObserver {
  ReplayPrivacyObserver({
    required String? Function() currentPath,
    required bool Function() consentGranted,
    ReplayRecordingControl control = const PosthogReplayRecordingControl(),
    Stream<void> Function()? consentChanges,
  }) : _currentPath = currentPath,
       _consentGranted = consentGranted,
       _control = control,
       _consentChanges = consentChanges;

  /// Observateur branché sur [AnalyticsService] : lit le consentement au
  /// moment de chaque changement d'écran. Le service n'est résolu qu'à la
  /// demande : le routeur est créé avant que l'injection soit prête (et sans
  /// elle dans les tests).
  factory ReplayPrivacyObserver.forAnalytics({
    required String? Function() currentPath,
    required AnalyticsService Function() analytics,
  }) => ReplayPrivacyObserver(
    currentPath: currentPath,
    consentGranted: () => analytics().isEnabled,
    consentChanges: () => analytics().consentChanges,
  );

  final String? Function() _currentPath;
  final bool Function() _consentGranted;
  final ReplayRecordingControl _control;
  final Stream<void> Function()? _consentChanges;

  bool _paused = false;
  StreamSubscription<void>? _consentSub;

  /// Visible dans les tests.
  bool get isPaused => _paused;

  /// Libère l'écoute du consentement.
  Future<void> dispose() async => _consentSub?.cancel();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _refresh();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _refresh();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _refresh();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _refresh();

  /// Le chemin courant n'est à jour qu'après la transition de page : lu à la
  /// frame suivante.
  void _refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) => evaluate());
  }

  /// Écoute les changements de consentement dès que le service est prêt.
  /// Sans service (tests, démarrage), on réessaiera au prochain écran.
  void _listenToConsent() {
    if (_consentSub != null || _consentChanges == null) return;
    try {
      _consentSub = _consentChanges().listen((_) => evaluate(force: true));
    } catch (_) {
      // Service d'analytics pas encore enregistré.
    }
  }

  /// Recalcule l'état voulu. [force] renvoie l'ordre d'arrêt même si l'état
  /// est déjà « en pause » : un accord de consentement relance
  /// l'enregistrement sans que l'observateur le sache.
  ///
  /// N'échoue jamais : la vie privée du replay ne doit pas faire planter la
  /// navigation.
  void evaluate({bool force = false}) {
    try {
      _listenToConsent();
      final path = _currentPath();
      final shouldPause = path != null && isReplaySensitivePath(path);
      if (shouldPause && (force || !_paused)) {
        _paused = true;
        unawaited(_control.stop());
      } else if (!shouldPause && _paused) {
        _paused = false;
        if (_consentGranted()) unawaited(_control.resume());
      }
    } catch (_) {
      // Chemin ou service indisponible : aucun changement d'état.
    }
  }
}
