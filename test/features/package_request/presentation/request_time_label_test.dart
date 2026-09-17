import 'package:dony/features/package_request/presentation/request_time_label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('moins d une minute', () {
    final now = DateTime.utc(2026, 9, 17, 8, 25, 30);
    expect(requestTimeLabel(DateTime.utc(2026, 9, 17, 8, 25), now: now), "publiée à l'instant");
  });

  test('minutes', () {
    final now = DateTime.utc(2026, 9, 17, 8, 50);
    expect(requestTimeLabel(DateTime.utc(2026, 9, 17, 8, 25), now: now), 'publiée il y a 25 min');
  });

  test('heures le même jour : le cas de la capture (06:25 UTC, 08:25 UTC)', () {
    final now = DateTime(2026, 9, 17, 10, 25);
    expect(requestTimeLabel(DateTime(2026, 9, 17, 8, 25), now: now), 'publiée il y a 2 h');
  });

  test('hier', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(requestTimeLabel(DateTime(2026, 9, 16, 8, 25), now: now), 'publiée hier, 08:25');
  });

  test('plus ancien', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(requestTimeLabel(DateTime(2026, 9, 12, 8, 25), now: now), 'publiée le 12 sept.');
  });

  test('verbe personnalisé', () {
    final now = DateTime(2026, 9, 17, 9);
    expect(requestTimeLabel(DateTime(2026, 9, 12), now: now, verb: 'créée'), 'créée le 12 sept.');
  });
}
