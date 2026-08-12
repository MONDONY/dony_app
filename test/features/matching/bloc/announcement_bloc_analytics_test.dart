import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}

class _MockHive extends Mock implements HiveService {}

class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockAnnouncementRepo repo;
  late MockAnalyticsBackend backend;
  late _MockHive hive;

  setUpAll(() {
    registerFallbackValue(const AddressData(label: 'dummy', lat: 0, lng: 0));
    registerFallbackValue(TransportMode.plane);
  });

  setUp(() {
    repo = _MockAnnouncementRepo();
    backend = MockAnalyticsBackend();
    hive = _MockHive();
    final box = _MockBox();
    when(() => hive.userPrefs).thenReturn(box);
    when(() => box.put(any(), any())).thenAnswer((_) async {});
    when(() => box.get(HiveService.kAnalyticsConsent)).thenReturn(true);
  });

  AnnouncementBloc makeBloc({bool enabled = true}) {
    final a = enabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    a.onConfigured();
    return AnnouncementBloc(repo, hive, a);
  }

  AnnouncementModel fakeAnnouncement() => AnnouncementModel(
    id: 'ann1',
    travelerId: 'traveler1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2024, 12, 1),
    availableKg: 10.0,
    totalKg: 10.0,
    pricePerKg: 15.0,
    status: 'ACTIVE',
    createdAt: DateTime(2024, 11, 1),
    updatedAt: DateTime(2024, 11, 1),
  );

  final fakeAddress = const AddressData(
    label: 'Paris CDG',
    lat: 48.8566,
    lng: 2.3522,
  );

  test(
    'announcement_created fires with corridor and metrics on success',
    () async {
      when(
        () => repo.createAnnouncement(
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
          description: any(named: 'description'),
          acceptedContentTypes: any(named: 'acceptedContentTypes'),
          refusedTypes: any(named: 'refusedTypes'),
          acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
          capacityUnit: any(named: 'capacityUnit'),
          pricingMode: any(named: 'pricingMode'),
          handoverWindowStart: any(named: 'handoverWindowStart'),
          handoverWindowEnd: any(named: 'handoverWindowEnd'),
        ),
      ).thenAnswer((_) async => fakeAnnouncement());

      final bloc = makeBloc();
      bloc.add(
        AnnouncementCreateRequested(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2024, 12, 1),
          pickupAddress: fakeAddress,
          deliveryAddress: fakeAddress,
          availableKg: 10.0,
          pricePerKg: 15.0,
          transportMode: TransportMode.plane,
          handoverWindowStart: DateTime(2026, 6, 14, 16),
          handoverWindowEnd: DateTime(2026, 6, 14, 18),
        ),
      );
      await bloc.stream.firstWhere((s) => s is AnnouncementCreated);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.announcementCreated, {
          'corridor': 'Paris→Dakar',
          'available_kg': 10.0,
          'price_per_kg': 15.0,
          'is_draft': false,
        }),
      ).called(1);
    },
  );

  test('surplus_opened fires with kg/price and no PII on success', () async {
    when(
      () => repo.openSurplus(
        announcementId: any(named: 'announcementId'),
        surplusKg: any(named: 'surplusKg'),
        pricePerKg: any(named: 'pricePerKg'),
      ),
    ).thenAnswer((_) async => fakeAnnouncement());

    final bloc = makeBloc();
    bloc.add(
      AnnouncementSurplusOpenRequested(
        announcementId: 'ann1',
        surplusKg: 8.0,
        pricePerKg: 7.0,
      ),
    );
    await bloc.stream.firstWhere((s) => s is AnnouncementSurplusOpened);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.surplusOpened, {
        'surplus_kg': 8.0,
        'price_per_kg': 7.0,
      }),
    ).called(1);
  });

  test('no event when analytics disabled', () async {
    when(
      () => repo.createAnnouncement(
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
        description: any(named: 'description'),
        acceptedContentTypes: any(named: 'acceptedContentTypes'),
        refusedTypes: any(named: 'refusedTypes'),
        acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
        capacityUnit: any(named: 'capacityUnit'),
        pricingMode: any(named: 'pricingMode'),
        handoverWindowStart: any(named: 'handoverWindowStart'),
        handoverWindowEnd: any(named: 'handoverWindowEnd'),
      ),
    ).thenAnswer((_) async => fakeAnnouncement());

    final bloc = makeBloc(enabled: false);
    bloc.add(
      AnnouncementCreateRequested(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2024, 12, 1),
        pickupAddress: fakeAddress,
        deliveryAddress: fakeAddress,
        availableKg: 10.0,
        pricePerKg: 15.0,
        transportMode: TransportMode.plane,
        handoverWindowStart: DateTime(2026, 6, 14, 16),
        handoverWindowEnd: DateTime(2026, 6, 14, 18),
      ),
    );
    await bloc.stream.firstWhere((s) => s is AnnouncementCreated);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
