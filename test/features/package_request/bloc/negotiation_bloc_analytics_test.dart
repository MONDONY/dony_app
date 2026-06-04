import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements NegotiationRepository {}

NegotiationThread _fakeThread({
  String id = 't-1',
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  List<NegotiationMessage> messages = const [],
  LinkedTripSummary? linkedTrip,
}) =>
    NegotiationThread(
      id: id,
      packageRequestId: 'pr-1',
      travelerId: 'tr-1',
      travelerTravelDate: DateTime(2026, 6, 15),
      travelerAvailableKg: 10,
      status: status,
      currentPriceEur: 30,
      roundsCount: 1,
      lastActivityAt: DateTime(2026, 5, 10),
      createdAt: DateTime(2026, 5, 10),
      messages: messages,
      linkedTrip: linkedTrip,
    );

void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    registerFallbackValue(PaymentMethod.stripe);
  });

  setUp(() {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  NegotiationBloc makeBloc({bool enabled = true}) {
    final analytics =
        enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return NegotiationBloc(repo, analytics: analytics);
  }

  // ── firm_price_taken ────────────────────────────────────────────────────────

  group('firm_price_taken', () {
    test('fires when isFirmPrice is true on start success', () async {
      when(() => repo.start(
            packageRequestId: any(named: 'packageRequestId'),
            proposedPriceEur: any(named: 'proposedPriceEur'),
            travelerTravelDate: any(named: 'travelerTravelDate'),
            travelerAvailableKg: any(named: 'travelerAvailableKg'),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => _fakeThread());

      final bloc = makeBloc();
      bloc.add(NegotiationStartRequested(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        isFirmPrice: true,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(
            AnalyticsEvents.firmPriceTaken,
            {'request_id': 'pr-1'},
          )).called(1);
      verifyNever(() => backend.capture(AnalyticsEvents.negotiationOfferMade, any()));
    });

    test('fires negotiation_offer_made (not firm_price_taken) when isFirmPrice is false',
        () async {
      when(() => repo.start(
            packageRequestId: any(named: 'packageRequestId'),
            proposedPriceEur: any(named: 'proposedPriceEur'),
            travelerTravelDate: any(named: 'travelerTravelDate'),
            travelerAvailableKg: any(named: 'travelerAvailableKg'),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => _fakeThread());

      final bloc = makeBloc();
      bloc.add(NegotiationStartRequested(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(AnalyticsEvents.negotiationOfferMade, any())).called(1);
      verifyNever(() => backend.capture(AnalyticsEvents.firmPriceTaken, any()));
    });

    test('does not fire when analytics disabled', () async {
      when(() => repo.start(
            packageRequestId: any(named: 'packageRequestId'),
            proposedPriceEur: any(named: 'proposedPriceEur'),
            travelerTravelDate: any(named: 'travelerTravelDate'),
            travelerAvailableKg: any(named: 'travelerAvailableKg'),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => _fakeThread());

      final bloc = makeBloc(enabled: false);
      bloc.add(NegotiationStartRequested(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        isFirmPrice: true,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(any(), any()));
    });
  });

  // ── payment_method_selected — submitTrip ────────────────────────────────────

  group('payment_method_selected (submitTrip)', () {
    test('fires with method wireName on submitTrip success', () async {
      when(() => repo.submitTrip(
            any(),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            paymentMethod: any(named: 'paymentMethod'),
          )).thenAnswer((_) async => _fakeThread(
            status: NegotiationThreadStatus.awaitingPayment,
          ));

      final bloc = makeBloc();
      bloc.add(const NegotiationSubmitTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.wave,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(
            AnalyticsEvents.paymentMethodSelected,
            {'method': 'WAVE'},
          )).called(1);
    });

    test('does not fire when analytics disabled', () async {
      when(() => repo.submitTrip(
            any(),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            paymentMethod: any(named: 'paymentMethod'),
          )).thenAnswer((_) async => _fakeThread());

      final bloc = makeBloc(enabled: false);
      bloc.add(const NegotiationSubmitTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.stripe,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(any(), any()));
    });
  });

  // ── payment_method_selected — createDedicatedTrip ───────────────────────────

  group('payment_method_selected (createDedicatedTrip)', () {
    test('fires with method wireName on createDedicatedTrip success', () async {
      when(() => repo.createDedicatedTrip(
            any(),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            description: any(named: 'description'),
            acceptedContentTypes: any(named: 'acceptedContentTypes'),
            refusedTypes: any(named: 'refusedTypes'),
            paymentMethod: any(named: 'paymentMethod'),
          )).thenAnswer((_) async => _fakeThread(
            status: NegotiationThreadStatus.awaitingPayment,
          ));

      final bloc = makeBloc();
      bloc.add(NegotiationCreateDedicatedTripRequested(
        threadId: 't-1',
        departureDate: DateTime(2026, 7, 1),
        pickupAddress: const {'city': 'Paris'},
        deliveryAddress: const {'city': 'Dakar'},
        paymentMethod: PaymentMethod.orangeMoney,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(
            AnalyticsEvents.paymentMethodSelected,
            {'method': 'ORANGE_MONEY'},
          )).called(1);
    });

    test('does not fire when analytics disabled', () async {
      when(() => repo.createDedicatedTrip(
            any(),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            description: any(named: 'description'),
            acceptedContentTypes: any(named: 'acceptedContentTypes'),
            refusedTypes: any(named: 'refusedTypes'),
            paymentMethod: any(named: 'paymentMethod'),
          )).thenAnswer((_) async => _fakeThread());

      final bloc = makeBloc(enabled: false);
      bloc.add(NegotiationCreateDedicatedTripRequested(
        threadId: 't-1',
        departureDate: DateTime(2026, 7, 1),
        pickupAddress: const {'city': 'Paris'},
        deliveryAddress: const {'city': 'Dakar'},
        paymentMethod: PaymentMethod.cash,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(any(), any()));
    });
  });
}
