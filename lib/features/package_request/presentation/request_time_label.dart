import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Verbe employé par [requestTimeLabel] : la demande a été « créée » (état
/// brouillon) ou « publiée » (sinon).
enum RequestTimeVerb { created, posted }

/// Libellé relatif d'une date de publication, toujours en heure locale.
String requestTimeLabel(
  DateTime createdAt, {
  required DateTime now,
  required AppLocalizations l10n,
  RequestTimeVerb verb = RequestTimeVerb.posted,
}) {
  final local = createdAt.toLocal();
  final nowLocal = now.toLocal();
  final diff = nowLocal.difference(local);
  final verbName = verb.name;
  if (diff.inMinutes < 1) return l10n.requestTimeJustNow(verbName);
  if (diff.inMinutes < 60) {
    return l10n.requestTimeMinutesAgo(verbName, diff.inMinutes);
  }

  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return l10n.requestTimeHoursAgo(verbName, diff.inHours);
  // Comparaison calendaire (DateTime(y, m, d - 1), normalisée par le
  // constructeur) plutôt que `today.difference(day).inDays == 1` : un
  // changement d'heure entre les deux jours (passage à l'heure d'été/hiver)
  // rend cette journée longue de 23 h ou 25 h réelles, et `.inDays` tronque
  // alors à 0 au lieu de 1 — « hier » n'apparaissait jamais ce jour-là.
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (day == yesterday) {
    return l10n.requestTimeYesterday(
      verbName,
      DateFormat.jm(l10n.localeName).format(local),
    );
  }
  return l10n.requestTimeOn(
    verbName,
    DateFormat.MMMd(l10n.localeName).format(local),
  );
}
