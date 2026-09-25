import 'package:dony/features/corridor_alerts/data/models/alert_notify_mode.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Libellés traduits de la fréquence de notification d'une alerte corridor.
extension AlertNotifyModeL10n on AlertNotifyMode {
  String label(AppLocalizations l) => switch (this) {
    AlertNotifyMode.instant => l.corridorAlertNotifyInstant,
    AlertNotifyMode.daily => l.corridorAlertNotifyDaily,
    AlertNotifyMode.muted => l.corridorAlertNotifySilent,
  };

  /// Phrase courte pour le bandeau de l'écran des correspondances.
  String description(AppLocalizations l) => switch (this) {
    AlertNotifyMode.instant => l.corridorAlertNotifyInstantDescription,
    AlertNotifyMode.daily => l.corridorAlertNotifyDailyDescription,
    AlertNotifyMode.muted => l.corridorAlertNotifySilentDescription,
  };
}

String _shortDate(AppLocalizations l, DateTime d) =>
    DateFormat.MMMd(l.localeName).format(d);

/// « 15 au 30 sept. », « À partir du 15 sept. », « Jusqu'au 30 sept. » ou
/// « Toute date ».
///
/// Même mois : la borne de départ n'affiche pas le mois en français
/// (« 15 au 30 sept. ») mais le doit en anglais (« Sep 15 to Sep 30 ») —
/// [AppLocalizations.corridorAlertSameMonthFromPattern] porte ce motif par
/// langue.
String corridorAlertDateLabel(AppLocalizations l, CorridorAlertModel a) {
  final from = a.dateFrom;
  final to = a.dateTo;
  if (from != null && to != null) {
    final sameMonth = from.year == to.year && from.month == to.month;
    final fromLabel = sameMonth
        ? DateFormat(
            l.corridorAlertSameMonthFromPattern,
            l.localeName,
          ).format(from)
        : _shortDate(l, from);
    return l.corridorAlertDateRange(fromLabel, _shortDate(l, to));
  }
  if (from != null) return l.corridorAlertDateFrom(_shortDate(l, from));
  if (to != null) return l.corridorAlertDateUntil(_shortDate(l, to));
  return l.corridorAlertAnyDate;
}

/// « ≥ 3 kg » ou « Tout poids » (alertes colis uniquement).
///
/// Le poids fractionnaire suit la langue (`formatOneDecimal`, virgule en
/// français) ; un poids entier reste sans décimale, comme avant (correction
/// R46 : le rendu précédent affichait toujours un point, y compris en
/// français, ex. « ≥ 2.5 kg »).
String corridorAlertWeightLabel(AppLocalizations l, CorridorAlertModel a) {
  final kg = a.minWeightKg;
  if (kg == null) return l.corridorAlertAnyWeight;
  final display = kg % 1 == 0 ? kg.toStringAsFixed(0) : formatOneDecimal(l, kg);
  return '≥ $display kg';
}
