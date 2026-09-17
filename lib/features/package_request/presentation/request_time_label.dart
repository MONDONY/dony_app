import 'package:intl/intl.dart';

/// Libellé relatif d'une date de publication, toujours en heure locale.
String requestTimeLabel(
  DateTime createdAt, {
  required DateTime now,
  String verb = 'publiée',
}) {
  final local = createdAt.toLocal();
  final nowLocal = now.toLocal();
  final diff = nowLocal.difference(local);
  if (diff.inMinutes < 1) return "$verb à l'instant";
  if (diff.inMinutes < 60) return '$verb il y a ${diff.inMinutes} min';

  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return '$verb il y a ${diff.inHours} h';
  // Comparaison calendaire (DateTime(y, m, d - 1), normalisée par le
  // constructeur) plutôt que `today.difference(day).inDays == 1` : un
  // changement d'heure entre les deux jours (passage à l'heure d'été/hiver)
  // rend cette journée longue de 23 h ou 25 h réelles, et `.inDays` tronque
  // alors à 0 au lieu de 1 — « hier » n'apparaissait jamais ce jour-là.
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (day == yesterday) {
    return '$verb hier, ${DateFormat('HH:mm', 'fr').format(local)}';
  }
  return '$verb le ${DateFormat('d MMM', 'fr').format(local)}';
}
