/// Le back sérialise ses `LocalDateTime` en UTC **sans fuseau**
/// (`2026-09-17T06:25:00`). `DateTime.parse` lirait alors une heure locale,
/// décalée de l'écart au fuseau (« publié à 06:25 » à 08:25 à Paris).
final RegExp _zoneSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

DateTime parseServerDateTime(String value) {
  final trimmed = value.trim();
  if (!trimmed.contains('T') || _zoneSuffix.hasMatch(trimmed)) {
    return DateTime.parse(trimmed);
  }
  return DateTime.parse('${trimmed}Z');
}
