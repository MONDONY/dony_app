import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_request_cubit.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidAmendmentRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid({TransportMode? mode, double? volume, double weight = 0}) =>
    BidModel(
      id: 'bid-1',
      announcementId: 'ann-1',
      senderId: 'sender-1',
      status: 'ACCEPTED',
      weightKg: weight,
      transportMode: mode,
      volumeM3: volume,
      createdAt: DateTime(2026, 11),
      updatedAt: DateTime(2026, 11),
    );

final _boatBid = _bid(mode: TransportMode.boat, volume: 0.5);

const _options = AmendmentOptions(
  currency: 'EUR',
  availableVolumeM3: 0.85,
  pricePerM3Display: 120,
  paymentMethods: [BidPaymentMethod.cash, BidPaymentMethod.stripe],
  minAmount: 1,
  maxAmount: 300,
);

const _kgOptions = AmendmentOptions(
  currency: 'EUR',
  availableKg: 6,
  pricePerKgDisplay: 5.13,
  paymentMethods: [BidPaymentMethod.cash],
  minAmount: 1,
  maxAmount: 300,
);

const _checkout = AmendmentCheckout(
  amendment: BidAmendment(
    id: 'am-1',
    status: BidAmendmentStatus.proposed,
    rail: 'CASH',
    addedVolumeM3: 0.3,
    grossAmount: 36,
  ),
);

void main() {
  late _MockRepository repository;
  late _MockAnalytics analytics;

  setUpAll(() => registerFallbackValue(BidPaymentMethod.cash));

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repository.options('bid-1')).thenAnswer((_) async => _options);
    when(
      () => repository.quote(
        'bid-1',
        addedKg: any(named: 'addedKg'),
        addedVolumeM3: any(named: 'addedVolumeM3'),
        items: any(named: 'items'),
      ),
    ).thenAnswer((_) async => 36);
    when(
      () => repository.create(
        'bid-1',
        addedKg: any(named: 'addedKg'),
        addedVolumeM3: any(named: 'addedVolumeM3'),
        items: any(named: 'items'),
        method: any(named: 'method'),
      ),
    ).thenAnswer((_) async => _checkout);
  });

  AmendmentRequestCubit build() => AmendmentRequestCubit(
    repository,
    analytics,
    quoteDebounce: const Duration(milliseconds: 10),
  );

  const settle = Duration(milliseconds: 60);

  test('isPricedPerM3_boatWithVolumeOnly', () {
    expect(_boatBid.isPricedPerM3, isTrue);
    expect(_bid(mode: TransportMode.boat).isPricedPerM3, isFalse);
    expect(_bid(mode: TransportMode.boat, volume: 0).isPricedPerM3, isFalse);
    expect(_bid(mode: TransportMode.plane, volume: 0.5).isPricedPerM3, isFalse);
    expect(_bid(volume: 0.5).isPricedPerM3, isFalse);
  });

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'boatAmendment_sendsVolume',
    build: build,
    act: (c) async {
      await c.load(_boatBid);
      c.setVolume(0.3);
      await Future<void>.delayed(settle);
      await c.submit();
    },
    verify: (c) {
      verify(
        () => repository.quote(
          'bid-1',
          addedKg: 0,
          addedVolumeM3: 0.3,
          items: const {},
        ),
      ).called(1);
      verify(
        () => repository.create(
          'bid-1',
          addedKg: 0,
          addedVolumeM3: 0.3,
          items: const {},
          method: BidPaymentMethod.cash,
        ),
      ).called(1);
      expect(c.state.grossQuote, 36);
      expect(c.state.status, AmendmentRequestStatus.sent);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentRequested,
          properties: {
            'method': 'cash',
            'added_kg': 0.0,
            'added_m3': 0.3,
            'price_unit': 'm3',
            'items_count': 0,
            'amount_bracket': analyticsAmountBracket(36),
            'currency': 'EUR',
          },
        ),
      ).called(1);
    },
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'boatAmendment_setVolume_stepsByTenth_clampedToFree',
    build: build,
    act: (c) async {
      await c.load(_boatBid);
      // 0,1 x 3 vaut 0,30000000000000004 en flottants.
      c.setVolume(0.1 * 3);
      expect(c.state.addedVolumeM3, 0.3);
      c.setVolume(0.34);
      expect(c.state.addedVolumeM3, 0.3);
      // 0,85 libre : plafond au dixième inférieur.
      c.setVolume(5);
      expect(c.state.addedVolumeM3, 0.8);
      c.setVolume(-1);
      expect(c.state.addedVolumeM3, 0);
    },
    wait: settle,
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'boatAmendment_openCapacity_capsFromNetCeiling',
    build: () {
      when(() => repository.options('bid-1')).thenAnswer(
        (_) async => const AmendmentOptions(
          currency: 'EUR',
          pricePerM3Display: 100,
          paymentMethods: [BidPaymentMethod.cash],
          minAmount: 1,
          maxAmount: 250,
        ),
      );
      return build();
    },
    act: (c) async {
      await c.load(_boatBid);
      c.setVolume(9);
    },
    wait: settle,
    verify: (c) => expect(c.state.addedVolumeM3, 2.5),
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'boatAmendment_loadAnalytics_carriesPriceUnit',
    build: build,
    act: (c) => c.load(_boatBid),
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidAmendmentSheetOpened,
        properties: {'rails_count': 2, 'price_unit': 'm3'},
      ),
    ).called(1),
  );

  blocTest<AmendmentRequestCubit, AmendmentRequestState>(
    'kgAmendment_unchanged',
    build: () {
      when(
        () => repository.options('bid-1'),
      ).thenAnswer((_) async => _kgOptions);
      return build();
    },
    act: (c) async {
      await c.load(_bid(mode: TransportMode.plane, weight: 5));
      // Sans effet sur un colis au kilo.
      c.setVolume(0.5);
      expect(c.state.addedVolumeM3, 0);
      c.setKg(2);
      await Future<void>.delayed(settle);
    },
    verify: (c) {
      verify(
        () => repository.quote(
          'bid-1',
          addedKg: 2,
          items: const {},
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentSheetOpened,
          properties: {'rails_count': 1},
        ),
      ).called(1);
    },
  );
}
