import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnnouncementRemoteDatasource extends Mock
    implements AnnouncementRemoteDatasource {}

const kPickup = AddressData(label: 'CDG Terminal 2', lat: 49.0097, lng: 2.5479);
const kDelivery = AddressData(
  label: 'Aéroport LSS',
  lat: 14.7397,
  lng: -17.4902,
);

AnnouncementModel _ann() => AnnouncementModel(
  id: 'ann-1',
  travelerId: 'traveler-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2024, 6),
  availableKg: 10.0,
  totalKg: 10.0,
  pricePerKg: 12.0,
  status: 'ACTIVE',
  createdAt: DateTime(2024, 5),
  updatedAt: DateTime(2024, 5),
);

void main() {
  late MockAnnouncementRemoteDatasource mockDs;
  late AnnouncementRepository repo;

  setUpAll(() {
    registerFallbackValue(kPickup);
    registerFallbackValue(TransportMode.other);
  });

  setUp(() {
    mockDs = MockAnnouncementRemoteDatasource();
    repo = AnnouncementRepository(mockDs);
  });

  test('createAnnouncement delegates correctly', () async {
    when(
      () => mockDs.createAnnouncement(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDate: any(named: 'departureDate'),
        departureTime: any(named: 'departureTime'),
        arrivalTime: any(named: 'arrivalTime'),
        pickupAddress: any(named: 'pickupAddress'),
        deliveryAddress: any(named: 'deliveryAddress'),
        availableKg: any(named: 'availableKg'),
        pricePerKg: any(named: 'pricePerKg'),
        transportMode: any(named: 'transportMode'),
        handoverDeadline: any(named: 'handoverDeadline'),
      ),
    ).thenAnswer((_) async => _ann());

    final result = await repo.createAnnouncement(
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2024, 6),
      pickupAddress: kPickup,
      deliveryAddress: kDelivery,
      availableKg: 10.0,
      pricePerKg: 12.0,
      transportMode: TransportMode.plane,
      handoverDeadline: DateTime(2026, 6, 14, 18),
    );
    expect(result.id, 'ann-1');
  });

  test('createAnnouncement forwards transportMode to datasource', () async {
    TransportMode? capturedMode;
    when(
      () => mockDs.createAnnouncement(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDate: any(named: 'departureDate'),
        departureTime: any(named: 'departureTime'),
        arrivalTime: any(named: 'arrivalTime'),
        pickupAddress: any(named: 'pickupAddress'),
        deliveryAddress: any(named: 'deliveryAddress'),
        availableKg: any(named: 'availableKg'),
        pricePerKg: any(named: 'pricePerKg'),
        transportMode: any(named: 'transportMode'),
        handoverDeadline: any(named: 'handoverDeadline'),
      ),
    ).thenAnswer((inv) async {
      capturedMode =
          inv.namedArguments[const Symbol('transportMode')] as TransportMode;
      return _ann();
    });

    await repo.createAnnouncement(
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2024, 6),
      pickupAddress: kPickup,
      deliveryAddress: kDelivery,
      availableKg: 10.0,
      pricePerKg: 12.0,
      transportMode: TransportMode.train,
      handoverDeadline: DateTime(2026, 6, 14, 18),
    );

    expect(capturedMode, TransportMode.train);
  });

  test('createAnnouncement propage saveAsDraft au datasource', () async {
    when(
      () => mockDs.createAnnouncement(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDate: any(named: 'departureDate'),
        departureTime: any(named: 'departureTime'),
        arrivalTime: any(named: 'arrivalTime'),
        pickupAddress: any(named: 'pickupAddress'),
        deliveryAddress: any(named: 'deliveryAddress'),
        availableKg: any(named: 'availableKg'),
        pricePerKg: any(named: 'pricePerKg'),
        transportMode: any(named: 'transportMode'),
        handoverDeadline: any(named: 'handoverDeadline'),
        saveAsDraft: any(named: 'saveAsDraft'),
      ),
    ).thenAnswer((_) async => _ann());

    await repo.createAnnouncement(
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2024, 6),
      pickupAddress: kPickup,
      deliveryAddress: kDelivery,
      availableKg: 10.0,
      pricePerKg: 12.0,
      transportMode: TransportMode.plane,
      handoverDeadline: DateTime(2026, 6, 14, 18),
      saveAsDraft: true,
    );

    final captured = verify(
      () => mockDs.createAnnouncement(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDate: any(named: 'departureDate'),
        departureTime: any(named: 'departureTime'),
        arrivalTime: any(named: 'arrivalTime'),
        pickupAddress: any(named: 'pickupAddress'),
        deliveryAddress: any(named: 'deliveryAddress'),
        availableKg: any(named: 'availableKg'),
        pricePerKg: any(named: 'pricePerKg'),
        transportMode: any(named: 'transportMode'),
        handoverDeadline: any(named: 'handoverDeadline'),
        saveAsDraft: captureAny(named: 'saveAsDraft'),
      ),
    ).captured;
    expect(captured.single, isTrue);
  });

  test('publishAnnouncement délègue au datasource', () async {
    final testAnnouncement = _ann();
    when(
      () => mockDs.publishAnnouncement('a1'),
    ).thenAnswer((_) async => testAnnouncement);

    final result = await repo.publishAnnouncement('a1');

    expect(result, same(testAnnouncement));
    verify(() => mockDs.publishAnnouncement('a1')).called(1);
  });

  test('unpublishAnnouncement délègue au datasource', () async {
    final testAnnouncement = _ann();
    when(
      () => mockDs.unpublishAnnouncement('a1'),
    ).thenAnswer((_) async => testAnnouncement);

    final result = await repo.unpublishAnnouncement('a1');

    expect(result, same(testAnnouncement));
    verify(() => mockDs.unpublishAnnouncement('a1')).called(1);
  });

  test('getMyAnnouncements delegates correctly', () async {
    when(
      () => mockDs.getMyAnnouncements(),
    ).thenAnswer((_) async => (announcements: [_ann()], totalElements: 1));

    final result = await repo.getMyAnnouncements();
    expect(result.announcements, hasLength(1));
    expect(result.totalElements, 1);
  });

  test('getAnnouncementDetail delegates correctly', () async {
    when(
      () => mockDs.getAnnouncementDetail('ann-1'),
    ).thenAnswer((_) async => _ann());

    final result = await repo.getAnnouncementDetail('ann-1');
    expect(result.departureCity, 'Paris');
  });

  test('searchAnnouncements delegates correctly', () async {
    when(
      () => mockDs.searchAnnouncements(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDateFrom: any(named: 'departureDateFrom'),
        departureDateTo: any(named: 'departureDateTo'),
        minAvailableKg: any(named: 'minAvailableKg'),
        sortBy: any(named: 'sortBy'),
        sortDir: any(named: 'sortDir'),
      ),
    ).thenAnswer((_) async => [_ann()]);

    final result = await repo.searchAnnouncements(departureCity: 'Paris');
    expect(result, hasLength(1));
  });

  test(
    'countAnnouncements délègue corridor, dates, position et rayon',
    () async {
      when(
        () => mockDs.countAnnouncements(
          departureCity: any(named: 'departureCity'),
          arrivalCity: any(named: 'arrivalCity'),
          departureDateFrom: any(named: 'departureDateFrom'),
          departureDateTo: any(named: 'departureDateTo'),
          minAvailableKg: any(named: 'minAvailableKg'),
          maxAvailableKg: any(named: 'maxAvailableKg'),
          maxPricePerKg: any(named: 'maxPricePerKg'),
          kiloProOnly: any(named: 'kiloProOnly'),
          minRating: any(named: 'minRating'),
          weekendOnly: any(named: 'weekendOnly'),
          transportMode: any(named: 'transportMode'),
          kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
          contentType: any(named: 'contentType'),
          userLat: any(named: 'userLat'),
          userLng: any(named: 'userLng'),
          radiusKm: any(named: 'radiusKm'),
          urgent: any(named: 'urgent'),
        ),
      ).thenAnswer((_) async => 7);

      final total = await repo.countAnnouncements(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDateFrom: DateTime(2026, 1, 5),
        userLat: 48.85,
        userLng: 2.35,
        radiusKm: 25,
        urgent: true,
      );

      expect(total, 7);
      verify(
        () => mockDs.countAnnouncements(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDateFrom: DateTime(2026, 1, 5),
          departureDateTo: any(named: 'departureDateTo'),
          minAvailableKg: any(named: 'minAvailableKg'),
          maxAvailableKg: any(named: 'maxAvailableKg'),
          maxPricePerKg: any(named: 'maxPricePerKg'),
          kiloProOnly: any(named: 'kiloProOnly'),
          minRating: any(named: 'minRating'),
          weekendOnly: any(named: 'weekendOnly'),
          transportMode: any(named: 'transportMode'),
          kycVerifiedOnly: any(named: 'kycVerifiedOnly'),
          contentType: any(named: 'contentType'),
          userLat: 48.85,
          userLng: 2.35,
          radiusKm: 25,
          urgent: true,
        ),
      ).called(1);
    },
  );

  test('openSurplus delegates correctly to datasource', () async {
    when(
      () => mockDs.openSurplus(
        announcementId: any(named: 'announcementId'),
        surplusKg: any(named: 'surplusKg'),
        pricePerKg: any(named: 'pricePerKg'),
      ),
    ).thenAnswer((_) async => _ann());

    final result = await repo.openSurplus(
      announcementId: 'ann-1',
      surplusKg: 8.0,
      pricePerKg: 7.0,
    );

    expect(result.id, 'ann-1');
    verify(
      () => mockDs.openSurplus(
        announcementId: 'ann-1',
        surplusKg: 8.0,
        pricePerKg: 7.0,
      ),
    ).called(1);
  });

  test('deleteAnnouncement delegates correctly', () async {
    when(() => mockDs.deleteAnnouncement('ann-1')).thenAnswer((_) async {});

    await expectLater(repo.deleteAnnouncement('ann-1'), completes);
  });

  test('updateAnnouncement delegates correctly', () async {
    when(
      () => mockDs.updateAnnouncement(
        id: any(named: 'id'),
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDate: any(named: 'departureDate'),
        departureTime: any(named: 'departureTime'),
        arrivalTime: any(named: 'arrivalTime'),
        pickupAddress: any(named: 'pickupAddress'),
        deliveryAddress: any(named: 'deliveryAddress'),
        availableKg: any(named: 'availableKg'),
        pricePerKg: any(named: 'pricePerKg'),
        transportMode: any(named: 'transportMode'),
        handoverDeadline: any(named: 'handoverDeadline'),
      ),
    ).thenAnswer((_) async => _ann());

    final result = await repo.updateAnnouncement(
      id: 'ann-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2024, 6),
      pickupAddress: kPickup,
      deliveryAddress: kDelivery,
      availableKg: 10.0,
      pricePerKg: 12.0,
      transportMode: TransportMode.car,
      handoverDeadline: DateTime(2026, 6, 14, 18),
    );
    expect(result.id, 'ann-1');
  });

  test('updateAnnouncement forwards transportMode to datasource', () async {
    TransportMode? capturedMode;
    when(
      () => mockDs.updateAnnouncement(
        id: any(named: 'id'),
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        departureDate: any(named: 'departureDate'),
        departureTime: any(named: 'departureTime'),
        arrivalTime: any(named: 'arrivalTime'),
        pickupAddress: any(named: 'pickupAddress'),
        deliveryAddress: any(named: 'deliveryAddress'),
        availableKg: any(named: 'availableKg'),
        pricePerKg: any(named: 'pricePerKg'),
        transportMode: any(named: 'transportMode'),
        handoverDeadline: any(named: 'handoverDeadline'),
      ),
    ).thenAnswer((inv) async {
      capturedMode =
          inv.namedArguments[const Symbol('transportMode')] as TransportMode;
      return _ann();
    });

    await repo.updateAnnouncement(
      id: 'ann-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2024, 6),
      pickupAddress: kPickup,
      deliveryAddress: kDelivery,
      availableKg: 10.0,
      pricePerKg: 12.0,
      transportMode: TransportMode.bus,
      handoverDeadline: DateTime(2026, 6, 14, 18),
    );

    expect(capturedMode, TransportMode.bus);
  });

  test('markTripArrived delegates to remote datasource', () async {
    final testAnnouncement = _ann();
    when(() => mockDs.markTripArrived(
            announcementId: 'a1', arrivalInstructions: 'x'))
        .thenAnswer((_) async => testAnnouncement);

    final result = await repo.markTripArrived(
        announcementId: 'a1', arrivalInstructions: 'x');

    expect(result, same(testAnnouncement));
    verify(() => mockDs.markTripArrived(
            announcementId: 'a1', arrivalInstructions: 'x'))
        .called(1);
  });

  test('updateArrivalInstructions delegates to remote datasource', () async {
    final testAnnouncement = _ann();
    when(() => mockDs.updateArrivalInstructions(
            announcementId: 'a1', arrivalInstructions: 'instructions'))
        .thenAnswer((_) async => testAnnouncement);

    final result = await repo.updateArrivalInstructions(
        announcementId: 'a1', arrivalInstructions: 'instructions');

    expect(result, same(testAnnouncement));
    verify(() => mockDs.updateArrivalInstructions(
            announcementId: 'a1', arrivalInstructions: 'instructions'))
        .called(1);
  });
}
