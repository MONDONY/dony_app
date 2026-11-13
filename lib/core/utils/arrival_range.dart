import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
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

/// Message du sélecteur de date d'arrivée pour une date saisie hors de la
/// fenêtre [first]..[last] (départ + [maxDays] au plus : 14 jours en route,
/// 120 en bateau, code back `arrival-too-far`). Remplace le « Hors de
/// portée. » de Material, qui ne dit pas la règle (recette du 13/11).
String arrivalOutOfRangeText(
  AppLocalizations l, {
  required DateTime first,
  required DateTime last,
  required int maxDays,
  DateTime? now,
}) {
  final days = arrivalRangeDays(l, first, last, now: now);
  return l.tripPublishArrivalOutOfRange(
    days.from,
    days.to ?? days.from,
    maxDays,
  );
}

/// Le message de plafond du sélecteur (saisie au clavier) tient sur plusieurs
/// lignes : sans cela Material le coupe sur une seule (« Choisissez entre le
/// 25 nov. et le 25 mar… », recette du 13/11) et la règle ne se lit pas.
/// À passer en `builder` de `showDatePicker`.
///
/// [colorScheme] : palette propre à l'écran appelant, appliquée ICI et non dans
/// un `Theme` imbriqué : un `Theme(data: Theme.of(ctx).copyWith(...))` posé
/// autour de ce builder repart du thème du dessus et en écraserait le réglage
/// des lignes d'erreur (recette du 13/11, trajet bateau).
Widget arrivalPickerBuilder(
  BuildContext context,
  Widget? child, {
  ColorScheme? colorScheme,
}) {
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      colorScheme: colorScheme ?? theme.colorScheme,
      datePickerTheme: theme.datePickerTheme.copyWith(
        inputDecorationTheme: const InputDecorationTheme(errorMaxLines: 5),
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
