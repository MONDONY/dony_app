import 'package:dony/features/matching/data/models/similar_announcement.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Phrase localisée décrivant l'écart entre un trajet proche et un critère de
/// la recherche. Un code inconnu, ou une valeur obligatoire vide, retombe sur
/// [AppLocalizations.unmetGeneric] : jamais de marqueur vide dans le texte.
String unmetCriterionLabel(
  AppLocalizations l,
  UnmetCriterion c, {
  required String localeName,
}) {
  final requested = c.requested.trim();
  final actual = c.actual.trim();
  final generic = l.unmetGeneric;

  switch (c.code) {
    case 'DATE':
      if (requested.isEmpty || actual.isEmpty) return generic;
      return l.unmetDate(
        _date(requested, localeName),
        _date(actual, localeName),
      );
    case 'AVAILABLE_KG':
      if (requested.isEmpty || actual.isEmpty) return generic;
      return l.unmetMinKg(requested, actual);
    case 'MAX_AVAILABLE_KG':
      if (requested.isEmpty || actual.isEmpty) return generic;
      return l.unmetMaxKg(requested, actual);
    case 'TRANSPORT_MODE':
      if (requested.isEmpty || actual.isEmpty) return generic;
      return l.unmetTransport(_transport(l, requested), _transport(l, actual));
    case 'MIN_RATING':
      if (requested.isEmpty || actual.isEmpty) return generic;
      return l.unmetMinRating(requested, actual);
    case 'CONTENT_TYPE':
      if (requested.isEmpty) return generic;
      return l.unmetContentType(requested);
    case 'RADIUS':
      return l.unmetRadius;
    case 'WEEKEND_ONLY':
      final day = _weekday(actual, localeName);
      return day == null ? generic : l.unmetWeekend(day);
    case 'URGENT':
      return l.unmetUrgent;
    case 'KILO_PRO_ONLY':
      return l.unmetGpPro;
    default:
      return generic;
  }
}

/// `yyyy-MM-dd` -> « 12 nov. » ; texte brut si la valeur n'est pas une date.
String _date(String raw, String localeName) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat.MMMd(localeName).format(parsed);
}

String _transport(AppLocalizations l, String raw) {
  final mode = transportModeFromWire(raw.toUpperCase());
  return mode?.label(l) ?? raw.toLowerCase();
}

// Lundi 2026-01-05 : date de référence pour obtenir le nom du jour localisé.
const _weekdays = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

String? _weekday(String raw, String localeName) {
  final index = _weekdays.indexOf(raw.toUpperCase());
  if (index < 0) return null;
  return DateFormat.EEEE(localeName).format(DateTime(2026, 1, 5 + index));
}
