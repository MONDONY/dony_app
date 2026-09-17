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
  if (today.difference(day).inDays == 1) {
    return '$verb hier, ${DateFormat('HH:mm', 'fr').format(local)}';
  }
  return '$verb le ${DateFormat('d MMM', 'fr').format(local)}';
}
