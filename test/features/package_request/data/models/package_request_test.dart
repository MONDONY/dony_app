import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PackageRequest.fromJson parses all fields', () {
    final json = {
      'id': 'aaa-111',
      'senderId': 'sender-1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'desiredDate': '2026-06-15',
      'dateToleranceDays': 2,
      'weightKg': 5.0,
      'parcelSize': 'SMALL',
      'contentCategory': 'Vêtements,Médicaments,Fragile',
      'description': 'Cadeau',
      'targetPriceEur': 25.5,
      'photoUrl': null,
      'pickupNeighborhood': '10e',
      'deliveryNeighborhood': 'Plateau',
      'status': 'OPEN',
      'createdAt': '2026-05-10T10:00:00Z',
    };

    final pr = PackageRequest.fromJson(json);

    expect(pr.id, 'aaa-111');
    expect(pr.parcelSize, ParcelSize.small);
    expect(pr.status, PackageRequestStatus.open);
    expect(pr.weightKg, 5.0);
    expect(pr.targetPriceEur, 25.5);
    // Catégories multiples : la chaîne wire est découpée par virgule.
    expect(pr.categories, ['Vêtements', 'Médicaments', 'Fragile']);
    expect(pr.primaryCategory, 'Vêtements');
  });

  test('fromJson parses negotiable + acceptedPaymentMethods', () {
    final json = {
      'id': '1',
      'senderId': 's',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'desiredDate': '2026-06-12',
      'dateToleranceDays': 2,
      'weightKg': 23,
      'parcelSize': 'LARGE',
      'transportMode': 'PLANE',
      'contentCategory': 'MEDICAMENTS',
      'status': 'OPEN',
      'createdAt': '2026-06-04T10:00:00',
      'negotiable': false,
      'acceptedPaymentMethods': ['STRIPE', 'CASH'],
    };
    final r = PackageRequest.fromJson(json);
    expect(r.negotiable, isFalse);
    expect(r.acceptedPaymentMethods, {
      PaymentMethod.stripe,
      PaymentMethod.cash,
    });
  });

  group('PackageRequest.grossPriceEur (brut pour un invité)', () {
    Map<String, dynamic> baseJson() => {
      'id': 'aaa-111',
      'senderId': 'sender-1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'desiredDate': '2026-06-15',
      'dateToleranceDays': 2,
      'weightKg': 5.0,
      'parcelSize': 'SMALL',
      'contentCategory': 'Vêtements',
      'targetPriceEur': 25.5,
      'status': 'OPEN',
      'createdAt': '2026-05-10T10:00:00Z',
    };

    test('grossPriceEur est lu quand le serveur le fournit', () {
      final json = baseJson()..['grossPriceEur'] = 28.0;

      final pr = PackageRequest.fromJson(json);

      expect(pr.grossPriceEur, 28.0);
    });

    test('grossPriceEur absent : nul, aucune exception', () {
      final json = baseJson();

      expect(PackageRequest.fromJson(json).grossPriceEur, isNull);
    });

    test('parses an integer grossPriceEur as a double', () {
      final json = baseJson()..['grossPriceEur'] = 28;

      final pr = PackageRequest.fromJson(json);

      expect(pr.grossPriceEur, 28.0);
    });

    test('grossPriceEur participates in equality (props)', () {
      final avec = PackageRequest.fromJson(
        baseJson()..['grossPriceEur'] = 28.0,
      );
      final sans = PackageRequest.fromJson(baseJson());
      expect(avec, isNot(equals(sans)));
    });
  });

  test('PackageRequest equality via Equatable', () {
    final json = {
      'id': 'a',
      'senderId': 's',
      'departureCity': 'A',
      'arrivalCity': 'B',
      'desiredDate': '2026-06-15',
      'dateToleranceDays': 2,
      'weightKg': 5.0,
      'parcelSize': 'SMALL',
      'contentCategory': 'cat',
      'status': 'OPEN',
      'createdAt': '2026-05-10T10:00:00Z',
    };
    expect(PackageRequest.fromJson(json), PackageRequest.fromJson(json));
  });
}
