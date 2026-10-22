import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/notifications/notification_route_resolver.dart';

/// Hôtes dont le lien `https://…/ouvrir` est un lien universel (iOS) / App Link
/// (Android) de l'app. Doit rester aligné sur `public/.well-known/*` de
/// yadony-web et sur les filtres du manifeste Android.
const openLinkHosts = {'yadony.com'};

/// Chemin du lien, côté site (`https://yadony.com/ouvrir`).
const openLinkPath = '/ouvrir';

final RegExp _typePattern = RegExp(r'^[A-Z][A-Z0-9_]{2,63}$');

/// Identifiants de charge utile repris du lien. Les mêmes que ceux que lit
/// [resolveNotificationRoute] : l'e-mail d'une notification ouvre donc l'écran
/// que le toucher du push ouvrirait.
const _idKeys = [
  'bidId',
  'announcementId',
  'requestId',
  'threadId',
  'cancellationId',
  'packageRequestId',
  'conversationId',
  'alertId',
];

/// Type de notification porté par un lien « Ouvrir Yadony » d'e-mail, ou `null`
/// si [uri] n'a pas cette forme.
///
/// Deux formes, même contrat :
/// - `https://yadony.com/ouvrir?type=BID_ACCEPTED&bidId={uuid}` (bouton des
///   e-mails, ouvert dans l'app par le système) ;
/// - `yadony://open?type=BID_ACCEPTED&bidId={uuid}` (bouton « Ouvrir dans
///   l'app » de la page de repli du site).
String? openLinkType(Uri uri) {
  final isCustomScheme =
      uri.scheme == 'yadony' &&
      uri.host == 'open' &&
      uri.pathSegments.every((segment) => segment.isEmpty);
  final isWebLink =
      uri.scheme == 'https' &&
      openLinkHosts.contains(uri.host) &&
      (uri.path == openLinkPath || uri.path == '$openLinkPath/');
  if (!isCustomScheme && !isWebLink) return null;
  final type = uri.queryParameters['type'];
  if (type == null || !_typePattern.hasMatch(type)) return null;
  return type;
}

/// Route GoRouter de la notification décrite par [uri], ou `null` (lien d'un
/// autre genre, type sans écran propre, identifiant invalide : le résolveur
/// partagé valide chaque UUID).
String? resolveOpenDeepLink(Uri uri) {
  final type = openLinkType(uri);
  if (type == null) return null;
  final data = <String, dynamic>{
    for (final key in _idKeys)
      if (uri.queryParameters[key] != null) key: uri.queryParameters[key],
  };
  return resolveNotificationRoute(type, data);
}

/// Traite un lien « Ouvrir Yadony » : l'écran de la notification s'ouvre par
/// [dispatch] (qui retient le lien sur un écran-porte : PIN, connexion).
///
/// Rend `false` si [uri] n'est pas un lien de ce genre. Un lien reconnu mais
/// sans écran (`resolved: false`) est consommé sans navigation : l'app reste
/// où elle s'ouvre.
bool handleOpenDeepLink(
  Uri uri, {
  required AnalyticsService analytics,
  required void Function(String route) dispatch,
}) {
  final type = openLinkType(uri);
  if (type == null) return false;
  final route = resolveOpenDeepLink(uri);
  unawaited(
    analytics.logEvent(
      AnalyticsEvents.emailLinkOpened,
      properties: {'type': type, 'resolved': route != null},
    ),
  );
  if (route != null) dispatch(route);
  return true;
}
