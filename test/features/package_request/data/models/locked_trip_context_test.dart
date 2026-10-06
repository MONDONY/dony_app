import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LockedTripContext', () {
    final base = LockedTripContext(
      threadId: 't-1',
      packageRequestId: 'pr-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 15),
      dateToleranceDays: 3,
      weightKg: 10.0,
      transportMode: TransportMode.plane,
      agreedPriceEur: 120.0,
    );

    test('earliestDate = desiredDate - dateToleranceDays', () {
      expect(base.earliestDate, DateTime(2026, 8, 12));
    });

    test('latestDate = desiredDate + dateToleranceDays', () {
      expect(base.latestDate, DateTime(2026, 8, 18));
    });

    test('default paymentMethod is stripe', () {
      expect(base.paymentMethod, PaymentMethod.stripe);
    });

    test('custom paymentMethod is stored', () {
      final ctx = LockedTripContext(
        threadId: 't-2',
        packageRequestId: 'pr-2',
        departureCity: 'Lyon',
        arrivalCity: 'Abidjan',
        desiredDate: DateTime(2026, 9),
        dateToleranceDays: 0,
        weightKg: 5.0,
        transportMode: TransportMode.car,
        agreedPriceEur: 60.0,
        paymentMethod: PaymentMethod.wave,
      );
      expect(ctx.paymentMethod, PaymentMethod.wave);
    });

    test('Equatable: equal when all props match', () {
      final copy = LockedTripContext(
        threadId: 't-1',
        packageRequestId: 'pr-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 8, 15),
        dateToleranceDays: 3,
        weightKg: 10.0,
        transportMode: TransportMode.plane,
        agreedPriceEur: 120.0,
      );
      expect(base, equals(copy));
    });

    test('Equatable: not equal when threadId differs', () {
      final other = LockedTripContext(
        threadId: 't-X',
        packageRequestId: 'pr-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 8, 15),
        dateToleranceDays: 3,
        weightKg: 10.0,
        transportMode: TransportMode.plane,
        agreedPriceEur: 120.0,
      );
      expect(base, isNot(equals(other)));
    });

    test('tolerance 0: earliestDate == latestDate == desiredDate', () {
      final ctx = LockedTripContext(
        threadId: 't-3',
        packageRequestId: 'pr-3',
        departureCity: 'Paris',
        arrivalCity: 'Bamako',
        desiredDate: DateTime(2026, 7),
        dateToleranceDays: 0,
        weightKg: 2.0,
        transportMode: TransportMode.train,
        agreedPriceEur: 40.0,
      );
      expect(ctx.earliestDate, ctx.desiredDate);
      expect(ctx.latestDate, ctx.desiredDate);
    });

    test('preferredDate est optionnel et participe à l\'égalité', () {
      expect(base.preferredDate, isNull);
      final withDate = LockedTripContext(
        threadId: 't-1',
        packageRequestId: 'pr-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime(2026, 8, 15),
        dateToleranceDays: 3,
        weightKg: 10.0,
        transportMode: TransportMode.plane,
        agreedPriceEur: 120.0,
        preferredDate: DateTime(2026, 8, 17),
      );
      expect(withDate, isNot(equals(base)));
    });
  });

  group('LockedTripContext.travelDateWindow (FLUTTER-E7)', () {
    test('fenêtre = souhaitée ± tolérance quand elle est à venir', () {
      final w = LockedTripContext.travelDateWindow(
        desiredDate: DateTime(2026, 8, 15),
        toleranceDays: 3,
        today: DateTime(2026, 7, 1, 18, 30),
      );
      expect(w.first, DateTime(2026, 8, 12));
      expect(w.last, DateTime(2026, 8, 18));
    });

    test('plancher à aujourd\'hui (jour calendaire, sans heure)', () {
      final w = LockedTripContext.travelDateWindow(
        desiredDate: DateTime(2026, 8, 15),
        toleranceDays: 3,
        today: DateTime(2026, 8, 14, 9),
      );
      expect(w.first, DateTime(2026, 8, 14));
      expect(w.last, DateTime(2026, 8, 18));
    });

    test('tolérance 0 : le jour même seulement', () {
      final w = LockedTripContext.travelDateWindow(
        desiredDate: DateTime(2026, 8, 15),
        toleranceDays: 0,
        today: DateTime(2026, 8),
      );
      expect(w.first, DateTime(2026, 8, 15));
      expect(w.last, DateTime(2026, 8, 15));
    });

    test('fenêtre passée : réduite à aujourd\'hui, jamais last < first', () {
      final w = LockedTripContext.travelDateWindow(
        desiredDate: DateTime(2026, 6, 12),
        toleranceDays: 3,
        today: DateTime(2026, 10, 7, 12),
      );
      expect(w.first, DateTime(2026, 10, 7));
      expect(w.last, DateTime(2026, 10, 7));
    });

    test('bornes calendaires à travers un changement d\'heure', () {
      final w = LockedTripContext.travelDateWindow(
        desiredDate: DateTime(2026, 3, 30),
        toleranceDays: 2,
        today: DateTime(2026, 3),
      );
      expect(w.first, DateTime(2026, 3, 28));
      expect(w.last, DateTime(2026, 4));
    });

    test('travelWindow d\'un contexte = travelDateWindow', () {
      final ctx = LockedTripContext(
        packageRequestId: 'pr-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime.now().add(const Duration(days: 30)),
        dateToleranceDays: 4,
        weightKg: 10.0,
        transportMode: TransportMode.plane,
        agreedPriceEur: 120.0,
      );
      final w = ctx.travelWindow;
      final expected = LockedTripContext.travelDateWindow(
        desiredDate: ctx.desiredDate,
        toleranceDays: ctx.dateToleranceDays,
      );
      expect(w, expected);
    });

    test('clampToWindow ramène une date dans la fenêtre', () {
      final w = (first: DateTime(2026, 8, 12), last: DateTime(2026, 8, 18));
      expect(
        LockedTripContext.clampToWindow(DateTime(2026, 8), w),
        DateTime(2026, 8, 12),
      );
      expect(
        LockedTripContext.clampToWindow(DateTime(2026, 9), w),
        DateTime(2026, 8, 18),
      );
      expect(
        LockedTripContext.clampToWindow(DateTime(2026, 8, 14, 15), w),
        DateTime(2026, 8, 14),
      );
    });
  });
}
