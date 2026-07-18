import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => setUrgencyThresholdDays(kUrgencyThresholdDaysDefault));

  test('seuil par défaut = 3', () {
    expect(urgencyThresholdDays, 3);
  });

  test('setUrgencyThresholdDays ignore les valeurs aberrantes', () {
    setUrgencyThresholdDays(0);
    expect(urgencyThresholdDays, 3);
    setUrgencyThresholdDays(-1);
    expect(urgencyThresholdDays, 3);
    setUrgencyThresholdDays(90);
    expect(urgencyThresholdDays, 3);
    setUrgencyThresholdDays(7);
    expect(urgencyThresholdDays, 7);
  });

  test('isUrgentDate : bornes exactes', () {
    setUrgencyThresholdDays(3);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(isUrgentDate(today), isTrue);
    expect(isUrgentDate(today.add(const Duration(days: 3))), isTrue);
    expect(isUrgentDate(today.add(const Duration(days: 4))), isFalse);
    expect(isUrgentDate(today.subtract(const Duration(days: 1))), isFalse);
  });

  test(
    'isUrgentDate : payload UTC équivalent à aujourd\'hui 23:59 (local) → urgent',
    () {
      // Une date parsée depuis un payload backend "...Z" est marquée UTC.
      // Sans conversion `.toLocal()` préalable, tronquer directement ses
      // composants UTC peut faire tomber sur le mauvais jour calendaire local
      // près de minuit. On simule ce payload en convertissant un instant
      // local connu (aujourd'hui 23:59) vers UTC.
      setUrgencyThresholdDays(3);
      final now = DateTime.now();
      final localToday2359 = DateTime(now.year, now.month, now.day, 23, 59);
      expect(isUrgentDate(localToday2359.toUtc()), isTrue);
    },
  );

  test(
    'isUrgentDate : borne haute (aujourd\'hui + seuil) avec une heure non-nulle → urgent',
    () {
      setUrgencyThresholdDays(3);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final atThresholdWithTime = today.add(
        const Duration(days: 3, hours: 14, minutes: 30),
      );
      expect(isUrgentDate(atThresholdWithTime.toUtc()), isTrue);
    },
  );
}
