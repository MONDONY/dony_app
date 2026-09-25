import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Ancienneté lisible de la dernière publication d'un voyageur.
///
/// Format court volontairement : la valeur s'affiche en bout de ligne, à côté
/// du nom, et doit rester lisible sans faire passer le nom à la ligne. Au-delà
/// d'une semaine on bascule sur la date, « il y a 23 j » ne disant plus rien.
///
/// [now] n'existe que pour les tests : par défaut c'est l'heure courante.
String subscriptionRecencyLabel(
  AppLocalizations l,
  DateTime publishedAt, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(publishedAt);

  // Une date future (horloge du téléphone en retard sur le serveur) se lit
  // « à l'instant » plutôt que « il y a -3 min ».
  if (diff.isNegative || diff.inMinutes < 1) return l.followRecencyJustNow;
  if (diff.inMinutes < 60) return l.followRecencyMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l.followRecencyHours(diff.inHours);
  if (diff.inDays == 1) return l.followRecencyYesterday;
  if (diff.inDays < 7) return l.followRecencyDays(diff.inDays);
  return DateFormat.MMMd(l.localeName).format(publishedAt);
}

/// Date de départ d'un trajet, en format court : « 27 sept. ».
///
/// L'année n'apparaît que si le départ ne tombe pas dans les douze mois à
/// venir : « 27 sept. » suffit pour un trajet proche, et l'année devient
/// indispensable au-delà.
String subscriptionDepartureLabel(
  AppLocalizations l,
  DateTime departure, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final horizon = DateTime(reference.year + 1, reference.month, reference.day);
  if (departure.isAfter(horizon)) {
    return DateFormat.yMMMd(l.localeName).format(departure);
  }
  return DateFormat.MMMd(l.localeName).format(departure);
}
