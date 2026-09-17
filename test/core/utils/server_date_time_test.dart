import 'package:dony/core/utils/server_date_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sans fuseau : lue comme UTC (LocalDateTime Spring)', () {
    final d = parseServerDateTime('2026-09-17T06:25:00');
    expect(d.isUtc, isTrue);
    expect(d.hour, 6);
  });

  test('avec fractions de seconde et sans fuseau : UTC', () {
    final d = parseServerDateTime('2026-09-17T06:25:00.123456');
    expect(d.isUtc, isTrue);
    expect(d.minute, 25);
  });

  test('avec Z : inchangée', () {
    expect(
      parseServerDateTime('2026-09-17T06:25:00Z'),
      DateTime.utc(2026, 9, 17, 6, 25),
    );
  });

  test('avec décalage : convertie en UTC', () {
    expect(
      parseServerDateTime('2026-09-17T08:25:00+02:00'),
      DateTime.utc(2026, 9, 17, 6, 25),
    );
  });

  test('date seule : parse standard', () {
    expect(parseServerDateTime('2026-09-17'), DateTime(2026, 9, 17));
  });
}
