import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
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
      'contentCategory': 'vetements',
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
  });

  test('PackageRequest equality via Equatable', () {
    final json = {
      'id': 'a', 'senderId': 's',
      'departureCity': 'A', 'arrivalCity': 'B',
      'desiredDate': '2026-06-15', 'dateToleranceDays': 2,
      'weightKg': 5.0, 'parcelSize': 'SMALL', 'contentCategory': 'cat',
      'status': 'OPEN', 'createdAt': '2026-05-10T10:00:00Z',
    };
    expect(PackageRequest.fromJson(json), PackageRequest.fromJson(json));
  });
}
