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
}
