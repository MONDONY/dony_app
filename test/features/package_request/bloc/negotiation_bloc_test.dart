import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
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
  String? clientSecret,
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
      paymentIntentClientSecret: clientSecret,
      linkedTrip: linkedTrip,
    );

NegotiationBloc _makeBloc(_MockRepo repo) => NegotiationBloc(
      repo,
      analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
    );

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(PaymentMethod.stripe);
  });

  setUp(() => repo = _MockRepo());

  blocTest<NegotiationBloc, NegotiationState>(
    'start emits Loading then Loaded with thread',
    build: () {
      when(() => repo.start(
            packageRequestId: any(named: 'packageRequestId'),
            proposedPriceEur: any(named: 'proposedPriceEur'),
            travelerTravelDate: any(named: 'travelerTravelDate'),
            travelerAvailableKg: any(named: 'travelerAvailableKg'),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => _fakeThread());
      return _makeBloc(repo);
    },
    act: (bloc) => bloc.add(NegotiationStartRequested(
      packageRequestId: 'pr-1',
      proposedPriceEur: 30,
      travelerTravelDate: DateTime(2026, 6, 15),
      travelerAvailableKg: 10,
    )),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>().having(
        (s) => s.thread.id,
        'thread.id',
        't-1',
      ),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'counter from Loaded emits ActionInProgress then Loaded',
    build: () {
      when(() => repo.counter(any(),
              proposedPriceEur: any(named: 'proposedPriceEur'),
              body: any(named: 'body')))
          .thenAnswer((_) async => _fakeThread(id: 't-1'));
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(const NegotiationCounterRequested(
      threadId: 't-1',
      proposedPriceEur: 25,
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationLoaded>(),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'accept returns thread with clientSecret',
    build: () {
      when(() => repo.accept(any(), body: any(named: 'body')))
          .thenAnswer((_) async => _fakeThread(
                status: NegotiationThreadStatus.accepted,
                clientSecret: 'pi_test_secret_xxx',
              ));
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) =>
        bloc.add(const NegotiationAcceptRequested(threadId: 't-1', body: 'OK')),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationLoaded>()
          .having((s) => s.thread.paymentIntentClientSecret,
              'paymentIntentClientSecret', 'pi_test_secret_xxx')
          .having((s) => s.thread.status, 'status',
              NegotiationThreadStatus.accepted),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'reject emits Rejected after success',
    build: () {
      when(() => repo.reject(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async {});
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(const NegotiationRejectRequested(
        threadId: 't-1', reason: 'too expensive')),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationRejected>()
          .having((s) => s.threadId, 'threadId', 't-1')
          .having((s) => s.cancelled, 'cancelled', false),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'cancel emits Rejected(cancelled: true) after success',
    build: () {
      when(() => repo.cancel(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async {});
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(const NegotiationCancelRequested(
        threadId: 't-1', reason: 'changed my mind')),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationRejected>()
          .having((s) => s.threadId, 'threadId', 't-1')
          .having((s) => s.cancelled, 'cancelled', true),
    ],
    verify: (_) => verify(
        () => repo.cancel('t-1', reason: 'changed my mind')).called(1),
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'cancel throws emits Error',
    build: () {
      when(() => repo.cancel(any(), reason: any(named: 'reason')))
          .thenThrow(Exception('server error'));
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(const NegotiationCancelRequested(threadId: 't-1')),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationError>(),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'counter throws emits Error',
    build: () {
      when(() => repo.counter(any(),
              proposedPriceEur: any(named: 'proposedPriceEur'),
              body: any(named: 'body')))
          .thenThrow(Exception('not your turn'));
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(const NegotiationCounterRequested(
        threadId: 't-1', proposedPriceEur: 25)),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationError>(),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'fetch emits Loading then Loaded',
    build: () {
      when(() => repo.getById(any())).thenAnswer((_) async => _fakeThread());
      return _makeBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationFetchRequested('t-1')),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>(),
    ],
  );

  // ── NegotiationRefuseTripRequested ──────────────────────────────────────────

  group('NegotiationRefuseTripRequested', () {
    const _linkedTrip = LinkedTripSummary(
      announcementId: 'ann-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 8,
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'emits [ActionInProgress, Loaded] on success when state is Loaded',
      build: () {
        when(() => repo.refuseTrip('t-1', reason: any(named: 'reason'))).thenAnswer(
          (_) async => _fakeThread(status: NegotiationThreadStatus.awaitingTrip),
        );
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread(
        status: NegotiationThreadStatus.awaitingPayment,
        linkedTrip: _linkedTrip,
      )),
      act: (bloc) =>
          bloc.add(const NegotiationRefuseTripRequested(threadId: 't-1')),
      expect: () => [
        isA<NegotiationActionInProgress>().having(
          (s) => s.thread.status,
          'thread.status',
          NegotiationThreadStatus.awaitingPayment,
        ),
        isA<NegotiationLoaded>().having(
          (s) => s.thread.status,
          'status',
          NegotiationThreadStatus.awaitingTrip,
        ),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'emits [Loading, Loaded] on success when initial state is not Loaded',
      build: () {
        when(() => repo.refuseTrip('t-1', reason: any(named: 'reason'))).thenAnswer(
          (_) async => _fakeThread(status: NegotiationThreadStatus.awaitingTrip),
        );
        return _makeBloc(repo);
      },
      act: (bloc) =>
          bloc.add(const NegotiationRefuseTripRequested(threadId: 't-1')),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationLoaded>().having(
          (s) => s.thread.status,
          'status',
          NegotiationThreadStatus.awaitingTrip,
        ),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'emits [ActionInProgress, Error] when refuseTrip throws',
      build: () {
        when(() => repo.refuseTrip(any(), reason: any(named: 'reason')))
            .thenThrow(Exception('server error'));
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread(
        status: NegotiationThreadStatus.awaitingPayment,
        linkedTrip: _linkedTrip,
      )),
      act: (bloc) =>
          bloc.add(const NegotiationRefuseTripRequested(threadId: 't-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>(),
      ],
    );
  });

  // ── NegotiationNudgeRequested ────────────────────────────────────────────────

  group('NegotiationNudgeRequested', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'nudge succès -> ActionInProgress puis NegotiationNudgeSent avec le thread rafraîchi',
      build: () {
        when(() => repo.nudge('t-1')).thenAnswer(
          (_) async => _fakeThread(status: NegotiationThreadStatus.open),
        );
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (bloc) => bloc.add(const NegotiationNudgeRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationNudgeSent>()
            .having((s) => s.thread.id, 'thread.id', 't-1'),
      ],
      verify: (_) => verify(() => repo.nudge('t-1')).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'nudge 429 rate-limited -> NegotiationNudgeError avec le code backend',
      build: () {
        when(() => repo.nudge('t-1')).thenThrow(
          const ValidationException('too soon', code: 'nudge/rate-limited'),
        );
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (bloc) => bloc.add(const NegotiationNudgeRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationNudgeError>()
            .having((s) => s.error.code, 'error.code', 'nudge/rate-limited'),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'nudge depuis un état autre que Loaded -> Loading puis NegotiationNudgeSent',
      build: () {
        when(() => repo.nudge('t-1')).thenAnswer((_) async => _fakeThread());
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const NegotiationNudgeRequested('t-1')),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationNudgeSent>(),
      ],
    );
  });

  // ── NegotiationCreateDedicatedTripRequested — useCardForCommission ─────────

  group('NegotiationCreateDedicatedTripRequested', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'threads useCardForCommission=true through to the repository call',
      build: () {
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
              useCardForCommission: any(named: 'useCardForCommission'),
            )).thenAnswer((_) async => _fakeThread(
              status: NegotiationThreadStatus.awaitingPayment,
            ));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(NegotiationCreateDedicatedTripRequested(
        threadId: 't-1',
        departureDate: DateTime(2026, 7, 1),
        pickupAddress: const {'label': 'Paris'},
        deliveryAddress: const {'label': 'Dakar'},
        paymentMethod: PaymentMethod.cash,
        useCardForCommission: true,
      )),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationLoaded>(),
      ],
      verify: (_) => verify(() => repo.createDedicatedTrip(
            't-1',
            departureDate: DateTime(2026, 7, 1),
            departureTime: null,
            arrivalTime: null,
            pickupAddress: const {'label': 'Paris'},
            deliveryAddress: const {'label': 'Dakar'},
            description: null,
            acceptedContentTypes: null,
            refusedTypes: null,
            paymentMethod: PaymentMethod.cash,
            useCardForCommission: true,
          )).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'defaults useCardForCommission to false when not specified',
      build: () {
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
              useCardForCommission: any(named: 'useCardForCommission'),
            )).thenAnswer((_) async => _fakeThread(
              status: NegotiationThreadStatus.awaitingPayment,
            ));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(NegotiationCreateDedicatedTripRequested(
        threadId: 't-1',
        departureDate: DateTime(2026, 7, 1),
        pickupAddress: const {'label': 'Paris'},
        deliveryAddress: const {'label': 'Dakar'},
        paymentMethod: PaymentMethod.stripe,
      )),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationLoaded>(),
      ],
      verify: (_) => verify(() => repo.createDedicatedTrip(
            't-1',
            departureDate: DateTime(2026, 7, 1),
            departureTime: null,
            arrivalTime: null,
            pickupAddress: const {'label': 'Paris'},
            deliveryAddress: const {'label': 'Dakar'},
            description: null,
            acceptedContentTypes: null,
            refusedTypes: null,
            paymentMethod: PaymentMethod.stripe,
            useCardForCommission: false,
          )).called(1),
    );
  });

  group('checkout — course avec le webhook Stripe', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'checkout 409 thread/not-awaiting-payment → recharge le thread et émet '
      'Loaded (paiement déjà finalisé par le webhook, pas d\'erreur)',
      build: () {
        when(() => repo.checkout('t-1',
                paymentIntentId: 'pi_1',
                paymentMethod: PaymentMethod.stripe))
            .thenThrow(const ConflictException('thread/not-awaiting-payment'));
        when(() => repo.getById('t-1')).thenAnswer(
            (_) async => _fakeThread(status: NegotiationThreadStatus.accepted));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const NegotiationCheckoutRequested(
        threadId: 't-1',
        paymentIntentId: 'pi_1',
        paymentMethod: PaymentMethod.stripe,
      )),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationLoaded>().having(
            (s) => s.thread.status, 'status', NegotiationThreadStatus.accepted),
      ],
      verify: (_) => verify(() => repo.getById('t-1')).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'checkout succès → Loaded',
      build: () {
        when(() => repo.checkout('t-1',
                paymentIntentId: 'pi_1',
                paymentMethod: PaymentMethod.stripe))
            .thenAnswer((_) async =>
                _fakeThread(status: NegotiationThreadStatus.accepted));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const NegotiationCheckoutRequested(
        threadId: 't-1',
        paymentIntentId: 'pi_1',
        paymentMethod: PaymentMethod.stripe,
      )),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationLoaded>(),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'checkout autre conflit → NegotiationError (erreur réelle non avalée)',
      build: () {
        when(() => repo.checkout('t-1',
                paymentIntentId: 'pi_1',
                paymentMethod: PaymentMethod.stripe))
            .thenThrow(const ConflictException('payment-method/not-accepted'));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const NegotiationCheckoutRequested(
        threadId: 't-1',
        paymentIntentId: 'pi_1',
        paymentMethod: PaymentMethod.stripe,
      )),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationError>(),
      ],
      verify: (_) => verifyNever(() => repo.getById(any())),
    );
  });
}
