import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchParams', () {
    test('constructs with required fields only', () {
      const params = SearchParams(departureCity: 'Paris', arrivalCity: 'Dakar');

      expect(params.departureCity, 'Paris');
      expect(params.arrivalCity, 'Dakar');
      expect(params.weightKg, 6);
      expect(params.maxPricePerKg, 25);
      expect(params.kiloProOnly, isFalse);
      expect(params.ratingFilter, isFalse);
      expect(params.weekendFilter, isFalse);
      expect(params.priceFilter, isFalse);
      expect(params.kycVerifiedOnly, isFalse);
      expect(params.transportMode, isNull);
      expect(params.contentType, isNull);
      expect(params.urgencyFilter, isNull);
      expect(params.date, isNull);
    });

    test('constructs without cities (nullable — BUG-009)', () {
      const params = SearchParams();

      expect(params.departureCity, isNull);
      expect(params.arrivalCity, isNull);
      expect(params.weightKg, 6);
    });

    test('constructs with all fields', () {
      final date = DateTime(2025, 6, 15);
      final params = SearchParams(
        departureCity: 'Lyon',
        arrivalCity: 'Abidjan',
        date: date,
        weightKg: 10,
        maxPricePerKg: 15,
        kiloProOnly: true,
        ratingFilter: true,
        weekendFilter: true,
        priceFilter: true,
        transportMode: TransportMode.plane,
        kycVerifiedOnly: true,
        contentType: 'CLOTHING',
        urgencyFilter: UrgencyFilter.urgent,
      );

      expect(params.departureCity, 'Lyon');
      expect(params.arrivalCity, 'Abidjan');
      expect(params.date, date);
      expect(params.weightKg, 10);
      expect(params.maxPricePerKg, 15);
      expect(params.kiloProOnly, isTrue);
      expect(params.ratingFilter, isTrue);
      expect(params.weekendFilter, isTrue);
      expect(params.priceFilter, isTrue);
      expect(params.transportMode, TransportMode.plane);
      expect(params.kycVerifiedOnly, isTrue);
      expect(params.contentType, 'CLOTHING');
      expect(params.urgencyFilter, UrgencyFilter.urgent);
    });
  });
}
