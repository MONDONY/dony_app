import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UrgencyFilter.matches', () {
    test('veryUrgent matches departure in 0–2 days', () {
      final today = DateTime.now();
      expect(UrgencyFilter.veryUrgent.matches(today), isTrue);
      expect(
        UrgencyFilter.veryUrgent.matches(today.add(const Duration(days: 1))),
        isTrue,
      );
      expect(
        UrgencyFilter.veryUrgent.matches(today.add(const Duration(days: 2))),
        isTrue,
      );
      expect(
        UrgencyFilter.veryUrgent.matches(today.add(const Duration(days: 3))),
        isFalse,
      );
    });

    test('urgent matches departure in 3–6 days', () {
      final today = DateTime.now();
      expect(
        UrgencyFilter.urgent.matches(today.add(const Duration(days: 3))),
        isTrue,
      );
      expect(
        UrgencyFilter.urgent.matches(today.add(const Duration(days: 6))),
        isTrue,
      );
      expect(
        UrgencyFilter.urgent.matches(today.add(const Duration(days: 7))),
        isFalse,
      );
      expect(
        UrgencyFilter.urgent.matches(today.add(const Duration(days: 2))),
        isFalse,
      );
    });

    test('soon matches departure in 7–13 days', () {
      final today = DateTime.now();
      expect(
        UrgencyFilter.soon.matches(today.add(const Duration(days: 7))),
        isTrue,
      );
      expect(
        UrgencyFilter.soon.matches(today.add(const Duration(days: 13))),
        isTrue,
      );
      expect(
        UrgencyFilter.soon.matches(today.add(const Duration(days: 14))),
        isFalse,
      );
      expect(
        UrgencyFilter.soon.matches(today.add(const Duration(days: 6))),
        isFalse,
      );
    });

    test('later matches departure in 14+ days', () {
      final today = DateTime.now();
      expect(
        UrgencyFilter.later.matches(today.add(const Duration(days: 14))),
        isTrue,
      );
      expect(
        UrgencyFilter.later.matches(today.add(const Duration(days: 30))),
        isTrue,
      );
      expect(
        UrgencyFilter.later.matches(today.add(const Duration(days: 13))),
        isFalse,
      );
    });

    test('each filter has non-empty label and tooltip', () {
      for (final filter in UrgencyFilter.values) {
        expect(filter.label, isNotEmpty);
        expect(filter.tooltip, isNotEmpty);
      }
    });

    test('each filter has a non-null color', () {
      for (final filter in UrgencyFilter.values) {
        expect(filter.color, isNotNull);
      }
    });

    test('filters are mutually exclusive for a given date', () {
      final today = DateTime.now();
      final dates = [
        today,
        today.add(const Duration(days: 3)),
        today.add(const Duration(days: 7)),
        today.add(const Duration(days: 14)),
      ];
      for (final date in dates) {
        final matchingFilters = UrgencyFilter.values
            .where((f) => f.matches(date))
            .toList();
        expect(
          matchingFilters,
          hasLength(1),
          reason: 'Exactly one filter should match date $date',
        );
      }
    });
  });
}
