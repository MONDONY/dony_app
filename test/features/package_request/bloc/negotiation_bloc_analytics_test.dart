import 'package:dony/core/error/app_exception.dart';
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

  // ── negotiation_nudge_sent ───────────────────────────────────────────────────

  group('negotiation_nudge_sent', () {
    test('fires on nudge success', () async {
      when(() => repo.nudge('t-1')).thenAnswer((_) async => _fakeThread());

      final bloc = makeBloc();
      bloc.add(const NegotiationNudgeRequested('t-1'));
      await bloc.stream.firstWhere((s) => s is NegotiationNudgeSent);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(AnalyticsEvents.negotiationNudgeSent, any()))
          .called(1);
    });

    test('does not fire on nudge failure', () async {
      when(() => repo.nudge('t-1')).thenThrow(
        const ValidationException('too soon', code: 'nudge/rate-limited'),
      );

      final bloc = makeBloc();
      bloc.add(const NegotiationNudgeRequested('t-1'));
      await bloc.stream.firstWhere((s) => s is NegotiationNudgeError);
      await Future<void>.delayed(Duration.zero);

      verifyNever(
          () => backend.capture(AnalyticsEvents.negotiationNudgeSent, any()));
    });

    test('does not fire when analytics disabled', () async {
      when(() => repo.nudge('t-1')).thenAnswer((_) async => _fakeThread());

      final bloc = makeBloc(enabled: false);
      bloc.add(const NegotiationNudgeRequested('t-1'));
      await bloc.stream.firstWhere((s) => s is NegotiationNudgeSent);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(any(), any()));
    });
  });

  // ── negotiation_cancelled ────────────────────────────────────────────────────

  group('negotiation_cancelled', () {
    test('fires on cancel success', () async {
      when(() => repo.cancel('t-1', reason: any(named: 'reason')))
          .thenAnswer((_) async {});

      final bloc = makeBloc();
      bloc.add(const NegotiationCancelRequested(threadId: 't-1'));
      await bloc.stream.firstWhere((s) => s is NegotiationRejected);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(AnalyticsEvents.negotiationCancelled, any()))
          .called(1);
    });

    test('does not fire on cancel failure', () async {
      when(() => repo.cancel('t-1', reason: any(named: 'reason')))
          .thenThrow(Exception('server error'));

      final bloc = makeBloc();
      bloc.add(const NegotiationCancelRequested(threadId: 't-1'));
      await bloc.stream.firstWhere((s) => s is NegotiationError);
      await Future<void>.delayed(Duration.zero);

      verifyNever(
          () => backend.capture(AnalyticsEvents.negotiationCancelled, any()));
    });

    test('does not fire when analytics disabled', () async {
      when(() => repo.cancel('t-1', reason: any(named: 'reason')))
          .thenAnswer((_) async {});

      final bloc = makeBloc(enabled: false);
      bloc.add(const NegotiationCancelRequested(threadId: 't-1'));
      await bloc.stream.firstWhere((s) => s is NegotiationRejected);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(any(), any()));
    });
  });

  // ── payment_method_selected no longer fires at trip-linking ─────────────────
  //
  // The traveler no longer picks a real payment method at trip-linking (the
  // back-end computes the capability SET; `paymentMethod` here is a
  // placeholder). The real user choice now happens at the sender's checkout
  // — see the `payment_method_selected (checkout)` group below.

  group('payment_method_selected no longer fires at trip-linking', () {
    test('submitTrip success does not fire payment_method_selected', () async {
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

      verifyNever(() => backend.capture(AnalyticsEvents.paymentMethodSelected, any()));
    });

    test('createDedicatedTrip success does not fire payment_method_selected',
        () async {
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
        departureDate: DateTime(2026, 7),
        pickupAddress: const {'city': 'Paris'},
        deliveryAddress: const {'city': 'Dakar'},
        paymentMethod: PaymentMethod.orangeMoney,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(AnalyticsEvents.paymentMethodSelected, any()));
    });
  });

  // ── payment_method_selected — checkout (sender's real choice) ──────────────

  group('payment_method_selected (checkout)', () {
    test('fires with method wireName on checkout success', () async {
      when(() => repo.checkout('t-1',
              paymentIntentId: 'pi_1', paymentMethod: PaymentMethod.wave))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.accepted));

      final bloc = makeBloc();
      bloc.add(const NegotiationCheckoutRequested(
        threadId: 't-1',
        paymentIntentId: 'pi_1',
        paymentMethod: PaymentMethod.wave,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(
            AnalyticsEvents.paymentMethodSelected,
            {'method': 'WAVE'},
          )).called(1);
    });

    test('does not fire when paymentMethod is null (backend keeps existing)',
        () async {
      when(() => repo.checkout('t-1', paymentIntentId: 'pi_1'))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.accepted));

      final bloc = makeBloc();
      bloc.add(const NegotiationCheckoutRequested(
        threadId: 't-1',
        paymentIntentId: 'pi_1',
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(AnalyticsEvents.paymentMethodSelected, any()));
    });

    test('fires on the webhook-race recovery path (409 thread/not-awaiting-payment)',
        () async {
      when(() => repo.checkout('t-1',
              paymentIntentId: 'pi_1', paymentMethod: PaymentMethod.stripe))
          .thenThrow(const ConflictException('thread/not-awaiting-payment'));
      when(() => repo.getById('t-1')).thenAnswer(
          (_) async => _fakeThread(status: NegotiationThreadStatus.accepted));

      final bloc = makeBloc();
      bloc.add(const NegotiationCheckoutRequested(
        threadId: 't-1',
        paymentIntentId: 'pi_1',
        paymentMethod: PaymentMethod.stripe,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(
            AnalyticsEvents.paymentMethodSelected,
            {'method': 'STRIPE'},
          )).called(1);
    });

    test('does not fire when analytics disabled', () async {
      when(() => repo.checkout('t-1',
              paymentIntentId: 'pi_1', paymentMethod: PaymentMethod.stripe))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.accepted));

      final bloc = makeBloc(enabled: false);
      bloc.add(const NegotiationCheckoutRequested(
        threadId: 't-1',
        paymentIntentId: 'pi_1',
        paymentMethod: PaymentMethod.stripe,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationLoaded);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(any(), any()));
    });
  });

  // ── trip_link_payment_blocked ────────────────────────────────────────────────

  group('trip_link_payment_blocked', () {
    test('fires with reason no_card on submitTrip 422 card-capability-required',
        () async {
      when(() => repo.submitTrip(
            any(),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            paymentMethod: any(named: 'paymentMethod'),
          )).thenThrow(const ValidationException(
        'no capable payment method',
        code: 'payment-method/card-capability-required',
      ));

      final bloc = makeBloc();
      bloc.add(const NegotiationSubmitTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.stripe,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationError);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(
            AnalyticsEvents.tripLinkPaymentBlocked,
            {'reason': 'no_card'},
          )).called(1);
    });

    test('fires with reason no_cash_funds on submitTrip 422 cash-funds-required',
        () async {
      when(() => repo.submitTrip(
            any(),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            paymentMethod: any(named: 'paymentMethod'),
          )).thenThrow(const ValidationException(
        'no capable payment method',
        code: 'payment-method/cash-funds-required',
      ));

      final bloc = makeBloc();
      bloc.add(const NegotiationSubmitTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.cash,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationError);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(
            AnalyticsEvents.tripLinkPaymentBlocked,
            {'reason': 'no_cash_funds'},
          )).called(1);
    });

    test('fires with reason none on createDedicatedTrip 422 none-available',
        () async {
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
          )).thenThrow(const ValidationException(
        'no capable payment method',
        code: 'payment-method/none-available',
      ));

      final bloc = makeBloc();
      bloc.add(NegotiationCreateDedicatedTripRequested(
        threadId: 't-1',
        departureDate: DateTime(2026, 7),
        pickupAddress: const {'city': 'Paris'},
        deliveryAddress: const {'city': 'Dakar'},
        paymentMethod: PaymentMethod.stripe,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationError);
      await Future<void>.delayed(Duration.zero);

      verify(() => backend.capture(
            AnalyticsEvents.tripLinkPaymentBlocked,
            {'reason': 'none'},
          )).called(1);
    });

    test('does not fire for an unrelated 422', () async {
      when(() => repo.submitTrip(
            any(),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            paymentMethod: any(named: 'paymentMethod'),
          )).thenThrow(const ValidationException(
        'unrelated validation error',
        code: 'trip/date-mismatch',
      ));

      final bloc = makeBloc();
      bloc.add(const NegotiationSubmitTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.stripe,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationError);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(AnalyticsEvents.tripLinkPaymentBlocked, any()));
    });

    test('does not fire when analytics disabled', () async {
      when(() => repo.submitTrip(
            any(),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            paymentMethod: any(named: 'paymentMethod'),
          )).thenThrow(const ValidationException(
        'no capable payment method',
        code: 'payment-method/card-capability-required',
      ));

      final bloc = makeBloc(enabled: false);
      bloc.add(const NegotiationSubmitTripRequested(
        threadId: 't-1',
        travelerAnnouncementId: 'ann-1',
        paymentMethod: PaymentMethod.stripe,
      ));
      await bloc.stream.firstWhere((s) => s is NegotiationError);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => backend.capture(any(), any()));
    });
  });
}
