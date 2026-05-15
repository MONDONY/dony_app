import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
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
        when(() => repo.refuseTrip('t-1')).thenAnswer(
          (_) async => _fakeThread(status: NegotiationThreadStatus.awaitingTrip),
        );
        return NegotiationBloc(repo);
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
        when(() => repo.refuseTrip('t-1')).thenAnswer(
          (_) async => _fakeThread(status: NegotiationThreadStatus.awaitingTrip),
        );
        return NegotiationBloc(repo);
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
        when(() => repo.refuseTrip(any()))
            .thenThrow(Exception('server error'));
        return NegotiationBloc(repo);
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
}
