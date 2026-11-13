import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_dio.dart';

const _json = <String, dynamic>{
  'id': 'pr-1',
  'senderId': 'sender-1',
  'departureCity': 'Paris',
  'arrivalCity': 'Abidjan',
  'weightKg': 40.0,
  'parcelSize': 'LARGE',
  'transportMode': 'BOAT',
  'contentCategory': 'Meubles',
  'status': 'OPEN',
  'createdAt': '2026-11-12T10:00:00Z',
  'lengthCm': 50,
  'widthCm': 40,
  'heightCm': 30,
  'volumeM3': 0.06,
};

/// Dimensions d'une demande en bateau dans le corps des requêtes : les trois
/// ensemble, jamais le volume, absentes quand il n'y en a pas.
void main() {
  late RecordingApi api;
  late PackageRequestRepository repo;

  setUp(() {
    api = RecordingApi();
    repo = PackageRequestRepository(api.client);
  });

  Future<void> create({int? l, int? w, int? h}) async {
    api.on('POST', '/package-requests', _json);
    await repo.create(
      departureCity: 'Paris',
      arrivalCity: 'Abidjan',
      desiredDate: null,
      dateToleranceDays: null,
      weightKg: 40,
      parcelSize: ParcelSize.large,
      transportMode: TransportMode.boat,
      categories: const ['Meubles'],
      negotiable: true,
      acceptedPaymentMethods: {PaymentMethod.stripe},
      totalBudgetEur: 600,
      lengthCm: l,
      widthCm: w,
      heightCm: h,
    );
  }

  test('create : lengthCm, widthCm, heightCm, jamais volumeM3', () async {
    await create(l: 50, w: 40, h: 30);
    final body = api.last.data as Map<String, dynamic>;
    expect(body['lengthCm'], 50);
    expect(body['widthCm'], 40);
    expect(body['heightCm'], 30);
    expect(body.containsKey('volumeM3'), isFalse);
    expect(body['transportMode'], 'BOAT');
  });

  test('create sans dimensions : clés absentes', () async {
    await create();
    final body = api.last.data as Map<String, dynamic>;
    expect(body.containsKey('lengthCm'), isFalse);
    expect(body.containsKey('widthCm'), isFalse);
    expect(body.containsKey('heightCm'), isFalse);
  });

  test(
    'update : dimensions envoyées, absentes = conservées par le back',
    () async {
      api.on('PUT', '/package-requests/pr-1', _json);
      Future<Map<String, dynamic>> update({int? l, int? w, int? h}) async {
        await repo.update(
          'pr-1',
          departureCity: 'Paris',
          arrivalCity: 'Abidjan',
          desiredDate: null,
          dateToleranceDays: null,
          weightKg: 40,
          parcelSize: ParcelSize.large,
          transportMode: TransportMode.boat,
          categories: const ['Meubles'],
          negotiable: true,
          acceptedPaymentMethods: {PaymentMethod.stripe},
          totalBudgetEur: 600,
          lengthCm: l,
          widthCm: w,
          heightCm: h,
        );
        return api.last.data as Map<String, dynamic>;
      }

      final withDims = await update(l: 60, w: 50, h: 40);
      expect(
        [withDims['lengthCm'], withDims['widthCm'], withDims['heightCm']],
        [60, 50, 40],
      );
      expect(withDims.containsKey('volumeM3'), isFalse);

      final without = await update();
      expect(without.containsKey('lengthCm'), isFalse);
      expect(without.containsKey('widthCm'), isFalse);
      expect(without.containsKey('heightCm'), isFalse);
    },
  );
}
