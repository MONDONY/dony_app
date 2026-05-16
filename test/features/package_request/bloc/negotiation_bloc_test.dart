import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements NegotiationRepository {}

NegotiationThread _fakeThread({
  String id = 't-1',
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  String? clientSecret,
  List<NegotiationMessage> messages = const [],
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
    );

void main() {
  late _MockRepo repo;

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
      return NegotiationBloc(repo);
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
      return NegotiationBloc(repo);
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
      return NegotiationBloc(repo);
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
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(const NegotiationRejectRequested(
        threadId: 't-1', reason: 'too expensive')),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationRejected>().having((s) => s.threadId, 'threadId', 't-1'),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'counter throws emits Error',
    build: () {
      when(() => repo.counter(any(),
              proposedPriceEur: any(named: 'proposedPriceEur'),
              body: any(named: 'body')))
          .thenThrow(Exception('not your turn'));
      return NegotiationBloc(repo);
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
      return NegotiationBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationFetchRequested('t-1')),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>(),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'refuseTrip depuis Loaded émet ActionInProgress puis Loaded',
    build: () {
      when(() => repo.refuseTrip(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingTrip));
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread(
        status: NegotiationThreadStatus.awaitingPayment)),
    act: (bloc) => bloc.add(const NegotiationRefuseTripRequested(
      threadId: 't-1',
      reason: 'Date trop tard',
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationLoaded>().having(
        (s) => s.thread.status,
        'thread.status',
        NegotiationThreadStatus.awaitingTrip,
      ),
    ],
    verify: (_) {
      verify(() => repo.refuseTrip('t-1', reason: 'Date trop tard')).called(1);
    },
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'refuseTrip émet Error quand le repository échoue',
    build: () {
      when(() => repo.refuseTrip(any(), reason: any(named: 'reason')))
          .thenThrow(Exception('boom'));
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread(
        status: NegotiationThreadStatus.awaitingPayment)),
    act: (bloc) => bloc.add(const NegotiationRefuseTripRequested(
      threadId: 't-1',
      reason: 'x',
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationError>(),
    ],
  );

  // ── fetch error ──────────────────────────────────────────────────────────────

  blocTest<NegotiationBloc, NegotiationState>(
    'fetch émet Loading puis Error si le repository échoue',
    build: () {
      when(() => repo.getById(any())).thenThrow(Exception('network error'));
      return NegotiationBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationFetchRequested('t-1')),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationError>(),
    ],
  );

  // ── start error ───────────────────────────────────────────────────────────────

  blocTest<NegotiationBloc, NegotiationState>(
    'start émet Loading puis Error si le repository échoue',
    build: () {
      when(() => repo.start(
            packageRequestId: any(named: 'packageRequestId'),
            proposedPriceEur: any(named: 'proposedPriceEur'),
            travelerTravelDate: any(named: 'travelerTravelDate'),
            travelerAvailableKg: any(named: 'travelerAvailableKg'),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            body: any(named: 'body'),
          )).thenThrow(Exception('server down'));
      return NegotiationBloc(repo);
    },
    act: (bloc) => bloc.add(NegotiationStartRequested(
      packageRequestId: 'pr-1',
      proposedPriceEur: 30,
      travelerTravelDate: DateTime(2026, 6, 15),
      travelerAvailableKg: 10,
    )),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationError>(),
    ],
  );

  // ── accept from non-Loaded state ─────────────────────────────────────────────

  blocTest<NegotiationBloc, NegotiationState>(
    'accept depuis état non-Loaded émet Loading puis Loaded',
    build: () {
      when(() => repo.accept(any(), body: any(named: 'body')))
          .thenAnswer((_) async => _fakeThread(
                status: NegotiationThreadStatus.accepted,
                clientSecret: 'pi_secret',
              ));
      return NegotiationBloc(repo);
    },
    // seed is NegotiationInitial (default)
    act: (bloc) =>
        bloc.add(const NegotiationAcceptRequested(threadId: 't-1')),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>()
          .having((s) => s.thread.status, 'status',
              NegotiationThreadStatus.accepted),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'accept émet Error quand le repository échoue',
    build: () {
      when(() => repo.accept(any(), body: any(named: 'body')))
          .thenThrow(Exception('conflict'));
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) =>
        bloc.add(const NegotiationAcceptRequested(threadId: 't-1')),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationError>(),
    ],
  );

  // ── reject from non-Loaded state ─────────────────────────────────────────────

  blocTest<NegotiationBloc, NegotiationState>(
    'reject depuis état non-Loaded émet Loading puis Rejected',
    build: () {
      when(() => repo.reject(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async {});
      return NegotiationBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationRejectRequested(threadId: 't-1')),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationRejected>().having((s) => s.threadId, 'threadId', 't-1'),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'reject émet Error quand le repository échoue',
    build: () {
      when(() => repo.reject(any(), reason: any(named: 'reason')))
          .thenThrow(Exception('forbidden'));
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc
        .add(const NegotiationRejectRequested(threadId: 't-1', reason: 'no')),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationError>(),
    ],
  );

  // ── submitTrip ────────────────────────────────────────────────────────────────

  blocTest<NegotiationBloc, NegotiationState>(
    'submitTrip depuis Loaded émet ActionInProgress puis Loaded',
    build: () {
      when(() => repo.submitTrip(any(),
              travelerAnnouncementId: any(named: 'travelerAnnouncementId')))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingPayment));
      return NegotiationBloc(repo);
    },
    seed: () =>
        NegotiationLoaded(_fakeThread(status: NegotiationThreadStatus.open)),
    act: (bloc) => bloc.add(const NegotiationSubmitTripRequested(
      threadId: 't-1',
      travelerAnnouncementId: 'ann-1',
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationLoaded>().having((s) => s.thread.status, 'status',
          NegotiationThreadStatus.awaitingPayment),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'submitTrip depuis état non-Loaded émet Loading puis Loaded',
    build: () {
      when(() => repo.submitTrip(any(),
              travelerAnnouncementId: any(named: 'travelerAnnouncementId')))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingPayment));
      return NegotiationBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationSubmitTripRequested(
      threadId: 't-1',
      travelerAnnouncementId: 'ann-1',
    )),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>(),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'submitTrip émet Error quand le repository échoue',
    build: () {
      when(() => repo.submitTrip(any(),
              travelerAnnouncementId: any(named: 'travelerAnnouncementId')))
          .thenThrow(Exception('mismatch'));
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(const NegotiationSubmitTripRequested(
      threadId: 't-1',
      travelerAnnouncementId: 'ann-1',
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationError>(),
    ],
  );

  // ── refuseTrip depuis état non-Loaded ─────────────────────────────────────────

  blocTest<NegotiationBloc, NegotiationState>(
    'refuseTrip depuis état non-Loaded émet Loading puis Loaded',
    build: () {
      when(() => repo.refuseTrip(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingTrip));
      return NegotiationBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationRefuseTripRequested(
      threadId: 't-1',
      reason: 'pas bon',
    )),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>().having((s) => s.thread.status, 'status',
          NegotiationThreadStatus.awaitingTrip),
    ],
  );

  // ── createDedicatedTrip ───────────────────────────────────────────────────────

  blocTest<NegotiationBloc, NegotiationState>(
    'createDedicatedTrip depuis Loaded émet ActionInProgress puis Loaded',
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
          )).thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingPayment));
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(NegotiationCreateDedicatedTripRequested(
      threadId: 't-1',
      departureDate: DateTime(2026, 6, 15),
      pickupAddress: const {'label': '10 rue de la Paix'},
      deliveryAddress: const {'label': 'Plateau, Dakar'},
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationLoaded>().having((s) => s.thread.status, 'status',
          NegotiationThreadStatus.awaitingPayment),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'createDedicatedTrip depuis état non-Loaded émet Loading puis Loaded',
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
          )).thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingPayment));
      return NegotiationBloc(repo);
    },
    act: (bloc) => bloc.add(NegotiationCreateDedicatedTripRequested(
      threadId: 't-1',
      departureDate: DateTime(2026, 6, 15),
      pickupAddress: const {'label': '10 rue de la Paix'},
      deliveryAddress: const {'label': 'Plateau, Dakar'},
    )),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>(),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'createDedicatedTrip émet Error quand le repository échoue',
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
          )).thenThrow(Exception('validation failed'));
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(NegotiationCreateDedicatedTripRequested(
      threadId: 't-1',
      departureDate: DateTime(2026, 6, 15),
      pickupAddress: const {'label': '10 rue de la Paix'},
      deliveryAddress: const {'label': 'Plateau, Dakar'},
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationError>(),
    ],
  );

  // ── checkout ─────────────────────────────────────────────────────────────────

  blocTest<NegotiationBloc, NegotiationState>(
    'checkout depuis Loaded émet ActionInProgress puis Loaded',
    build: () {
      when(() => repo.checkout(any(),
              paymentIntentId: any(named: 'paymentIntentId')))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.accepted));
      return NegotiationBloc(repo);
    },
    seed: () =>
        NegotiationLoaded(_fakeThread(status: NegotiationThreadStatus.awaitingPayment)),
    act: (bloc) => bloc.add(const NegotiationCheckoutRequested(
      threadId: 't-1',
      paymentIntentId: 'pi_xxx',
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationLoaded>().having((s) => s.thread.status, 'status',
          NegotiationThreadStatus.accepted),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'checkout depuis état non-Loaded émet Loading puis Loaded',
    build: () {
      when(() => repo.checkout(any(),
              paymentIntentId: any(named: 'paymentIntentId')))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.accepted));
      return NegotiationBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationCheckoutRequested(
      threadId: 't-1',
      paymentIntentId: 'pi_xxx',
    )),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>(),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'checkout émet Error quand le repository échoue',
    build: () {
      when(() => repo.checkout(any(),
              paymentIntentId: any(named: 'paymentIntentId')))
          .thenThrow(Exception('payment failed'));
      return NegotiationBloc(repo);
    },
    seed: () =>
        NegotiationLoaded(_fakeThread(status: NegotiationThreadStatus.awaitingPayment)),
    act: (bloc) => bloc.add(const NegotiationCheckoutRequested(
      threadId: 't-1',
      paymentIntentId: 'pi_xxx',
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationError>(),
    ],
  );

  // ── counter depuis état non-Loaded ────────────────────────────────────────────

  blocTest<NegotiationBloc, NegotiationState>(
    'counter depuis état non-Loaded émet Loading puis Loaded',
    build: () {
      when(() => repo.counter(any(),
              proposedPriceEur: any(named: 'proposedPriceEur'),
              body: any(named: 'body')))
          .thenAnswer((_) async => _fakeThread(id: 't-1'));
      return NegotiationBloc(repo);
    },
    // No seed → NegotiationInitial
    act: (bloc) => bloc.add(const NegotiationCounterRequested(
      threadId: 't-1',
      proposedPriceEur: 25,
    )),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>(),
    ],
  );

  // ── NegotiationStartRequested props ───────────────────────────────────────────

  test('NegotiationStartRequested.props inclut tous les champs', () {
    final date = DateTime(2026, 6, 15);
    final event = NegotiationStartRequested(
      packageRequestId: 'pr-1',
      proposedPriceEur: 30,
      travelerTravelDate: date,
      travelerAvailableKg: 10,
      travelerAnnouncementId: 'ann-1',
      body: 'hello',
    );
    expect(
      event.props,
      equals(['pr-1', 30.0, date, 10.0, 'ann-1', 'hello']),
    );
  });

  test('NegotiationCreateDedicatedTripRequested.props inclut tous les champs', () {
    final date = DateTime(2026, 6, 15);
    final event = NegotiationCreateDedicatedTripRequested(
      threadId: 't-1',
      departureDate: date,
      departureTime: '10:00',
      arrivalTime: '20:00',
      pickupAddress: const {'label': 'Paris'},
      deliveryAddress: const {'label': 'Dakar'},
      description: 'desc',
      acceptedContentTypes: const ['electronics'],
      refusedTypes: const ['food'],
    );
    expect(event.props, contains('t-1'));
    expect(event.props, contains(date));
  });

  test('NegotiationCheckoutRequested.props inclut threadId et paymentIntentId', () {
    const event =
        NegotiationCheckoutRequested(threadId: 't-1', paymentIntentId: 'pi_x');
    expect(event.props, equals(['t-1', 'pi_x']));
  });

  test('NegotiationSubmitTripRequested.props inclut threadId et announcementId', () {
    const event = NegotiationSubmitTripRequested(
        threadId: 't-1', travelerAnnouncementId: 'ann-1');
    expect(event.props, equals(['t-1', 'ann-1']));
  });

  test('NegotiationCounterRequested.props inclut tous les champs', () {
    const event = NegotiationCounterRequested(
        threadId: 't-1', proposedPriceEur: 25, body: 'ok');
    expect(event.props, equals(['t-1', 25.0, 'ok']));
  });

  test('NegotiationFetchRequested.props inclut threadId', () {
    const event = NegotiationFetchRequested('t-1');
    expect(event.props, equals(['t-1']));
  });

  test('NegotiationRefuseTripRequested.props inclut threadId et reason', () {
    const event =
        NegotiationRefuseTripRequested(threadId: 't-1', reason: 'raison');
    expect(event.props, equals(['t-1', 'raison']));
  });

  test('NegotiationRejectRequested.props inclut threadId et reason', () {
    const event =
        NegotiationRejectRequested(threadId: 't-1', reason: 'trop cher');
    expect(event.props, equals(['t-1', 'trop cher']));
  });

  test('NegotiationAcceptRequested.props inclut threadId et body', () {
    const event = NegotiationAcceptRequested(threadId: 't-1', body: 'ok');
    expect(event.props, equals(['t-1', 'ok']));
  });

  test('NegotiationActionInProgress.props inclut le thread', () {
    final thread = _fakeThread();
    final state = NegotiationActionInProgress(thread);
    expect(state.props, equals([thread]));
  });

  test('NegotiationLoaded.props inclut le thread', () {
    final thread = _fakeThread();
    final state = NegotiationLoaded(thread);
    expect(state.props, equals([thread]));
  });

  test('NegotiationError.props inclut l\'erreur', () {
    const error = NetworkException('test error');
    final state = NegotiationError(error);
    expect(state.props, equals([error]));
  });

  test('NegotiationRejected.props inclut threadId', () {
    const state = NegotiationRejected('t-1');
    expect(state.props, equals(['t-1']));
  });
}
