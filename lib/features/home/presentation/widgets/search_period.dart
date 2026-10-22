// Période de départ choisie au calendrier dans la recherche (composeur et
// feuille « Date de départ » de l'accueil) : un seul libellé et un seul
// sélecteur pour les deux, afin que le champ et la puce disent la même chose.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Libellé d'une période de recherche, dans la langue [locale].
///
/// Un seul jour ([end] absent ou le même jour) garde le format d'avant les
/// périodes : « 30 oct. » (`MMMd`), ou « ven. 30 oct. » (`MMMEd`) avec
/// [withWeekday]. Une période s'écrit « 15 nov. → 15 déc. ». L'année
/// n'apparaît que si elle aide : à la fin d'une période d'une autre année que
/// [now], sur les deux bornes d'une période à cheval sur deux années.
String formatSearchPeriod(
  DateTime start,
  DateTime? end,
  String locale, {
  bool withWeekday = false,
  DateTime? now,
}) {
  if (end == null || DateUtils.isSameDay(start, end)) {
    return (withWeekday ? DateFormat.MMMEd(locale) : DateFormat.MMMd(locale))
        .format(start);
  }
  final short = DateFormat.MMMd(locale);
  final withYear = DateFormat.yMMMd(locale);
  if (start.year != end.year) {
    return '${withYear.format(start)} → ${withYear.format(end)}';
  }
  final currentYear = (now ?? DateTime.now()).year;
  final endLabel = end.year == currentYear
      ? short.format(end)
      : withYear.format(end);
  return '${short.format(start)} → $endLabel';
}

/// Ouvre le calendrier de période (du jour même à deux ans), prérempli avec
/// la période en cours quand elle tient encore dans ces bornes. Rend `null`
/// si l'utilisateur referme sans choisir. Le même jour touché deux fois donne
/// une période d'un seul jour (`start == end`).
Future<DateTimeRange?> showSearchPeriodPicker(
  BuildContext context, {
  DateTime? start,
  DateTime? end,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final lastDate = DateTime(today.year + 2, today.month, today.day);
  DateTimeRange? initial;
  if (start != null) {
    final from = DateUtils.dateOnly(start);
    final to = DateUtils.dateOnly(end ?? start);
    if (!from.isBefore(today) && !to.isAfter(lastDate)) {
      initial = DateTimeRange(start: from, end: to);
    }
  }
  final primary = Theme.of(context).colorScheme.primary;
  return showDateRangePicker(
    context: context,
    firstDate: today,
    lastDate: lastDate,
    initialDateRange: initial,
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: primary),
      ),
      child: child!,
    ),
  );
}
