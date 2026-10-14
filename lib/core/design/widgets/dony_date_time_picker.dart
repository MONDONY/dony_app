import 'package:flutter/material.dart';

/// Résultat de [pickDateThenTime] : le jour toujours, l'heure seulement si
/// le second sélecteur n'a pas été annulé.
@immutable
class DonyDateTimePick {
  const DonyDateTimePick({required this.day, this.time});

  /// Jour choisi, à minuit.
  final DateTime day;

  /// Heure choisie, `null` si le sélecteur d'heure a été fermé sans valider :
  /// l'appelant applique alors sa propre heure de repli.
  final TimeOfDay? time;

  /// Instant complet, ou `null` quand l'heure n'a pas été choisie.
  DateTime? get instant => time == null
      ? null
      : DateTime(day.year, day.month, day.day, time!.hour, time!.minute);

  /// Instant complet, ou le jour à l'heure rendue par [fallback] quand
  /// l'heure n'a pas été choisie.
  DateTime resolve(DateTime Function(DateTime day) fallback) =>
      instant ?? fallback(day);
}

/// Choix d'un jour puis d'une heure en un seul geste : le calendrier, puis
/// aussitôt le sélecteur d'heure (retour testeur FLUTTER-PK : la date limite
/// de dépôt n'avait qu'un calendrier, son heure était déduite sans jamais
/// être choisie).
///
/// Rend `null` si le calendrier est annulé. Si seul le sélecteur d'heure est
/// annulé, le jour est rendu avec `time == null`.
///
/// [initialTimeFor] reçoit le jour choisi : l'heure proposée peut dépendre de
/// lui (le jour du départ, l'heure de départ). [primary] reprend le thème des
/// sélecteurs de l'écran appelant (`ColorScheme.light(primary: …)`), sinon le
/// thème courant s'applique tel quel.
Future<DonyDateTimePick?> pickDateThenTime(
  BuildContext context, {
  required DateTime first,
  required DateTime last,
  DateTime? initial,
  TimeOfDay Function(DateTime day)? initialTimeFor,
  Color? primary,
}) async {
  final firstDay = DateUtils.dateOnly(first);
  final lastDay = DateUtils.dateOnly(last).isBefore(firstDay)
      ? firstDay
      : DateUtils.dateOnly(last);
  var initialDay = DateUtils.dateOnly(initial ?? lastDay);
  if (initialDay.isBefore(firstDay)) initialDay = firstDay;
  if (initialDay.isAfter(lastDay)) initialDay = lastDay;

  Widget themed(BuildContext ctx, Widget? child) => primary == null
      ? child!
      : Theme(
          data: Theme.of(
            ctx,
          ).copyWith(colorScheme: ColorScheme.light(primary: primary)),
          child: child!,
        );

  final day = await showDatePicker(
    context: context,
    initialDate: initialDay,
    firstDate: firstDay,
    lastDate: lastDay,
    builder: themed,
  );
  if (day == null) return null;
  final picked = DateUtils.dateOnly(day);
  if (!context.mounted) return DonyDateTimePick(day: picked);
  final time = await showTimePicker(
    context: context,
    initialTime:
        initialTimeFor?.call(picked) ?? const TimeOfDay(hour: 20, minute: 0),
    builder: themed,
  );
  return DonyDateTimePick(day: picked, time: time);
}
