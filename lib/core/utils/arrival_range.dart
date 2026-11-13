import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Arrivée estimée mise en jours lisibles (« 11 janv. », « 18 janv. »).
///
/// [to] vaut `null` pour une date seule : fin absente, le même jour que le
/// début, ou avant lui. Les dates se lisent en jours calendaires (année, mois,
/// jour tels que servis), sans heure ni fuseau. Un jour d'une autre année que
/// celle de [now] porte son année.
typedef ArrivalRangeDays = ({String from, String? to});

ArrivalRangeDays arrivalRangeDays(
  AppLocalizations l,
  DateTime from,
  DateTime? to, {
  DateTime? now,
}) {
  final year = (now ?? DateTime.now()).year;
  String day(DateTime d) =>
      (d.year == year
              ? DateFormat.MMMd(l.localeName)
              : DateFormat.yMMMd(l.localeName))
          .format(d);
  final sameDay =
      to != null &&
      to.year == from.year &&
      to.month == from.month &&
      to.day == from.day;
  if (to == null || sameDay || to.isBefore(from)) {
    return (from: day(from), to: null);
  }
  return (from: day(from), to: day(to));
}
