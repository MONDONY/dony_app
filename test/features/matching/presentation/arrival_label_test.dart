import 'package:dony/features/matching/presentation/arrival_label.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

// FLUTTER-4E : heure d'arrivée avec le décalage de jour.
void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);
  final dep = DateTime(2026, 10, 4);

  test('même jour ou date absente : heure seule', () {
    expect(
      arrivalTimeLabel(fr, '14:30', departureDate: dep, arrivalDate: null),
      '14:30',
    );
    expect(
      arrivalTimeLabel(fr, '14:30', departureDate: dep, arrivalDate: dep),
      '14:30',
    );
  });

  test('lendemain : (+1 j) en français, (+1d) en anglais', () {
    final next = DateTime(2026, 10, 5);
    expect(
      arrivalTimeLabel(fr, '06:30', departureDate: dep, arrivalDate: next),
      '06:30 (+1 j)',
    );
    expect(
      arrivalTimeLabel(en, '06:30', departureDate: dep, arrivalDate: next),
      '06:30 (+1d)',
    );
  });
}
