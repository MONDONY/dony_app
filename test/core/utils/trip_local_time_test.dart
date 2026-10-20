import 'package:dony/core/utils/trip_local_time.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppLocalizations fr;
  late AppLocalizations en;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    fr = lookupAppLocalizations(const Locale('fr'));
    en = lookupAppLocalizations(const Locale('en'));
  });

  // 20 juillet : heure d'été à Paris (UTC+2).
  final instant = DateTime.utc(2027, 7, 20, 18, 30);

  group('tripWallTime (PROD-1R)', () {
    test('18:30Z à Paris → 20:30 heure murale', () {
      final t = tripWallTime(
        instant,
        'Europe/Paris',
        deviceOffset: const Duration(hours: 2),
      );
      expect(t.wallClock.hour, 20);
      expect(t.wallClock.minute, 30);
      expect(t.wallClock.day, 20);
      expect(t.differsFromDevice, isFalse);
      expect(formatTripTime(fr, t, city: 'Paris'), '20:30');
    });

    test('appareil à Dakar (UTC+0) → « 20:30, heure de Paris »', () {
      final t = tripWallTime(
        instant,
        'Europe/Paris',
        deviceOffset: Duration.zero,
      );
      expect(t.differsFromDevice, isTrue);
      expect(formatTripTime(fr, t, city: 'Paris'), '20:30, heure de Paris');
      // intl sépare l'heure de « PM » par une espace fine insécable.
      expect(
        formatTripTime(en, t, city: 'Paris').replaceAll('\u202f', ' '),
        '8:30 PM, Paris time',
      );
    });

    test('ville à voyelle : élision « heure d\'Abidjan »', () {
      final t = tripWallTime(
        instant,
        'Africa/Abidjan',
        deviceOffset: const Duration(hours: 2),
      );
      expect(t.wallClock.hour, 18);
      expect(formatTripTime(fr, t, city: 'Abidjan'), "18:30, heure d'Abidjan");
    });

    test('heure d\'hiver : 18:30Z en janvier → 19:30 à Paris', () {
      final t = tripWallTime(
        DateTime.utc(2027, 1, 20, 18, 30),
        'Europe/Paris',
        deviceOffset: const Duration(hours: 1),
      );
      expect(t.wallClock.hour, 19);
      expect(t.differsFromDevice, isFalse);
    });

    test('fuseau absent (ancien back) → heure de l\'appareil, sans ville', () {
      final t = tripWallTime(instant, null);
      final local = instant.toLocal();
      expect(t.wallClock.hour, local.hour);
      expect(t.wallClock.minute, local.minute);
      expect(t.differsFromDevice, isFalse);
      expect(formatTripTime(fr, t, city: 'Paris'), isNot(contains('heure')));
    });

    test('fuseau inconnu ou vide → repli toLocal', () {
      expect(tripWallTime(instant, 'Mars/Olympus').differsFromDevice, isFalse);
      expect(
        tripWallTime(instant, '  ').wallClock.hour,
        instant.toLocal().hour,
      );
    });

    test('ville absente → heure seule même si le fuseau diffère', () {
      final t = tripWallTime(
        instant,
        'Europe/Paris',
        deviceOffset: Duration.zero,
      );
      expect(formatTripTime(fr, t), '20:30');
      expect(formatTripTime(fr, t, city: ' '), '20:30');
    });
  });
}
