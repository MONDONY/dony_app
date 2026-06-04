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
        desiredDate: DateTime(2026, 9, 1),
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
        desiredDate: DateTime(2026, 7, 1),
        dateToleranceDays: 0,
        weightKg: 2.0,
        transportMode: TransportMode.train,
        agreedPriceEur: 40.0,
      );
      expect(ctx.earliestDate, ctx.desiredDate);
      expect(ctx.latestDate, ctx.desiredDate);
    });
  });
}
