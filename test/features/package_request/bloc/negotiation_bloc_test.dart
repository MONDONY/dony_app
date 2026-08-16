import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
// `flutter_stripe` also exports a `PaymentMethod` class which collides with
// dony's own `PaymentMethod` enum imported above — hide it.
import 'package:flutter_stripe/flutter_stripe.dart' hide PaymentMethod;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements NegotiationRepository {}

class _MockStripe extends Mock implements Stripe {}

PaymentIntent _fakePaymentIntent() => const PaymentIntent(
  id: 'pi_x',
  amount: 100,
  created: '1234567890',
  currency: 'eur',
  status: PaymentIntentsStatus.Succeeded,
  clientSecret: 'pi_x_secret',
  livemode: false,
  captureMethod: CaptureMethod.Automatic,
  confirmationMethod: ConfirmationMethod.Automatic,
);

NegotiationThread _fakeThread({
  String id = 't-1',
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  String? clientSecret,
  List<NegotiationMessage> messages = const [],
  LinkedTripSummary? linkedTrip,
}) => NegotiationThread(
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

NegotiationBloc _makeBloc(_MockRepo repo, {Stripe? stripe}) => NegotiationBloc(
  repo,
  analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
  stripe: stripe,
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
      when(
        () => repo.start(
          packageRequestId: any(named: 'packageRequestId'),
          proposedPriceEur: any(named: 'proposedPriceEur'),
          travelerTravelDate: any(named: 'travelerTravelDate'),
          travelerAvailableKg: any(named: 'travelerAvailableKg'),
          travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _fakeThread());
      return _makeBloc(repo);
    },
    act: (bloc) => bloc.add(
      NegotiationStartRequested(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
      ),
    ),
    expect: () => [
      isA<NegotiationLoading>(),
      isA<NegotiationLoaded>().having((s) => s.thread.id, 'thread.id', 't-1'),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'start forwards createDedicatedTrip and dedicatedTripPayload unmodified '
    'to repository.start',
    build: () {
      when(
        () => repo.start(
          packageRequestId: any(named: 'packageRequestId'),
          proposedPriceEur: any(named: 'proposedPriceEur'),
          travelerTravelDate: any(named: 'travelerTravelDate'),
          travelerAvailableKg: any(named: 'travelerAvailableKg'),
          travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
          body: any(named: 'body'),
          createDedicatedTrip: any(named: 'createDedicatedTrip'),
          dedicatedTripPayload: any(named: 'dedicatedTripPayload'),
        ),
      ).thenAnswer((_) async => _fakeThread());
      return _makeBloc(repo);
    },
    act: (bloc) => bloc.add(
      NegotiationStartRequested(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        createDedicatedTrip: true,
        dedicatedTripPayload: const {
          'departureDate': '2026-07-01',
          'pickupAddress': {'label': 'Paris'},
          'deliveryAddress': {'label': 'Dakar'},
        },
      ),
    ),
    expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
    verify: (_) => verify(
      () => repo.start(
        packageRequestId: 'pr-1',
        proposedPriceEur: 30,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        createDedicatedTrip: true,
        dedicatedTripPayload: const {
          'departureDate': '2026-07-01',
          'pickupAddress': {'label': 'Paris'},
          'deliveryAddress': {'label': 'Dakar'},
        },
      ),
    ).called(1),
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'NegotiationStartWithDedicatedTripRequested calls repository.start with '
    'createDedicatedTrip=true',
    build: () {
      when(
        () => repo.start(
          packageRequestId: any(named: 'packageRequestId'),
          proposedPriceEur: any(named: 'proposedPriceEur'),
          travelerTravelDate: any(named: 'travelerTravelDate'),
          travelerAvailableKg: any(named: 'travelerAvailableKg'),
          travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
          body: any(named: 'body'),
          createDedicatedTrip: any(named: 'createDedicatedTrip'),
          dedicatedTripPayload: any(named: 'dedicatedTripPayload'),
        ),
      ).thenAnswer((_) async => _fakeThread());
      return _makeBloc(repo);
    },
    act: (bloc) => bloc.add(
      NegotiationStartWithDedicatedTripRequested(
        packageRequestId: 'req-1',
        proposedPriceEur: 42,
        travelerTravelDate: DateTime(2026, 9),
        travelerAvailableKg: 5,
        dedicatedTrip: DedicatedTripPayload(
          departureDate: DateTime(2026, 9),
          pickupAddress: const {'label': 'Pickup', 'lat': 48.8, 'lng': 2.3},
          deliveryAddress: const {'label': 'Delivery', 'lat': 5.3, 'lng': -4.0},
        ),
      ),
    ),
    expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
    verify: (_) => verify(
      () => repo.start(
        packageRequestId: 'req-1',
        proposedPriceEur: 42,
        travelerTravelDate: DateTime(2026, 9),
        travelerAvailableKg: 5,
        createDedicatedTrip: true,
        dedicatedTripPayload: any(named: 'dedicatedTripPayload'),
      ),
    ).called(1),
  );

  test(
    'DedicatedTripPayload.toJson omits nulls and includes required fields',
    () {
      final payload = DedicatedTripPayload(
        departureDate: DateTime(2026, 9),
        pickupAddress: const {'label': 'Pickup', 'lat': 48.8, 'lng': 2.3},
        deliveryAddress: const {'label': 'Delivery', 'lat': 5.3, 'lng': -4.0},
      );
      final json = payload.toJson();
      expect(json['departureDate'], '2026-09-01');
      expect(json['pickupAddress'], {
        'label': 'Pickup',
        'lat': 48.8,
        'lng': 2.3,
      });
      expect(json['deliveryAddress'], {
        'label': 'Delivery',
        'lat': 5.3,
        'lng': -4.0,
      });
      expect(json['useCardForCommission'], false);
      expect(json.containsKey('departureTime'), isFalse);
      expect(json.containsKey('arrivalTime'), isFalse);
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('acceptedContentTypes'), isFalse);
      expect(json.containsKey('refusedTypes'), isFalse);
    },
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'counter from Loaded emits ActionInProgress then Loaded',
    build: () {
      when(
        () => repo.counter(
          any(),
          proposedPriceEur: any(named: 'proposedPriceEur'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _fakeThread());
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(
      const NegotiationCounterRequested(threadId: 't-1', proposedPriceEur: 25),
    ),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationLoaded>(),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'accept returns thread with clientSecret',
    build: () {
      when(() => repo.accept(any(), body: any(named: 'body'))).thenAnswer(
        (_) async => _fakeThread(
          status: NegotiationThreadStatus.accepted,
          clientSecret: 'pi_test_secret_xxx',
        ),
      );
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) =>
        bloc.add(const NegotiationAcceptRequested(threadId: 't-1', body: 'OK')),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationLoaded>()
          .having(
            (s) => s.thread.paymentIntentClientSecret,
            'paymentIntentClientSecret',
            'pi_test_secret_xxx',
          )
          .having(
            (s) => s.thread.status,
            'status',
            NegotiationThreadStatus.accepted,
          ),
    ],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'reject emits Rejected after success',
    build: () {
      when(
        () => repo.reject(any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async {});
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(
      const NegotiationRejectRequested(
        threadId: 't-1',
        reason: 'too expensive',
      ),
    ),
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
      when(
        () => repo.cancel(any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async {});
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(
      const NegotiationCancelRequested(
        threadId: 't-1',
        reason: 'changed my mind',
      ),
    ),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationRejected>()
          .having((s) => s.threadId, 'threadId', 't-1')
          .having((s) => s.cancelled, 'cancelled', true),
    ],
    verify: (_) =>
        verify(() => repo.cancel('t-1', reason: 'changed my mind')).called(1),
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'cancel throws emits Error',
    build: () {
      when(
        () => repo.cancel(any(), reason: any(named: 'reason')),
      ).thenThrow(Exception('server error'));
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(const NegotiationCancelRequested(threadId: 't-1')),
    expect: () => [isA<NegotiationActionInProgress>(), isA<NegotiationError>()],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'counter throws emits Error',
    build: () {
      when(
        () => repo.counter(
          any(),
          proposedPriceEur: any(named: 'proposedPriceEur'),
          body: any(named: 'body'),
        ),
      ).thenThrow(Exception('not your turn'));
      return _makeBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread()),
    act: (bloc) => bloc.add(
      const NegotiationCounterRequested(threadId: 't-1', proposedPriceEur: 25),
    ),
    expect: () => [isA<NegotiationActionInProgress>(), isA<NegotiationError>()],
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'fetch emits Loading then Loaded',
    build: () {
      when(() => repo.getById(any())).thenAnswer((_) async => _fakeThread());
      return _makeBloc(repo);
    },
    act: (bloc) => bloc.add(const NegotiationFetchRequested('t-1')),
    expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
  );

  // ── NegotiationRefuseTripRequested ──────────────────────────────────────────

  group('NegotiationRefuseTripRequested', () {
    const linkedTrip = LinkedTripSummary(
      announcementId: 'ann-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 8,
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'emits [ActionInProgress, Loaded] on success when state is Loaded',
      build: () {
        when(
          () => repo.refuseTrip('t-1', reason: any(named: 'reason')),
        ).thenAnswer(
          (_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingTrip),
        );
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(
        _fakeThread(
          status: NegotiationThreadStatus.awaitingPayment,
          linkedTrip: linkedTrip,
        ),
      ),
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
        when(
          () => repo.refuseTrip('t-1', reason: any(named: 'reason')),
        ).thenAnswer(
          (_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingTrip),
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
        when(
          () => repo.refuseTrip(any(), reason: any(named: 'reason')),
        ).thenThrow(Exception('server error'));
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(
        _fakeThread(
          status: NegotiationThreadStatus.awaitingPayment,
          linkedTrip: linkedTrip,
        ),
      ),
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
        when(() => repo.nudge('t-1')).thenAnswer((_) async => _fakeThread());
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (bloc) => bloc.add(const NegotiationNudgeRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationNudgeSent>().having(
          (s) => s.thread.id,
          'thread.id',
          't-1',
        ),
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
        isA<NegotiationNudgeError>().having(
          (s) => s.error.code,
          'error.code',
          'nudge/rate-limited',
        ),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'nudge depuis un état autre que Loaded -> Loading puis NegotiationNudgeSent',
      build: () {
        when(() => repo.nudge('t-1')).thenAnswer((_) async => _fakeThread());
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(const NegotiationNudgeRequested('t-1')),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationNudgeSent>()],
    );
  });

  // ── NegotiationCreateDedicatedTripRequested — useCardForCommission ─────────

  group('NegotiationCreateDedicatedTripRequested', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'threads useCardForCommission=true through to the repository call',
      build: () {
        when(
          () => repo.createDedicatedTrip(
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
          ),
        ).thenAnswer(
          (_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingPayment),
        );
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(
        NegotiationCreateDedicatedTripRequested(
          threadId: 't-1',
          departureDate: DateTime(2026, 7),
          pickupAddress: const {'label': 'Paris'},
          deliveryAddress: const {'label': 'Dakar'},
          paymentMethod: PaymentMethod.cash,
          useCardForCommission: true,
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
      verify: (_) => verify(
        () => repo.createDedicatedTrip(
          't-1',
          departureDate: DateTime(2026, 7),
          pickupAddress: const {'label': 'Paris'},
          deliveryAddress: const {'label': 'Dakar'},
          paymentMethod: PaymentMethod.cash,
          useCardForCommission: true,
        ),
      ).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'defaults useCardForCommission to false when not specified',
      build: () {
        when(
          () => repo.createDedicatedTrip(
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
          ),
        ).thenAnswer(
          (_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingPayment),
        );
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(
        NegotiationCreateDedicatedTripRequested(
          threadId: 't-1',
          departureDate: DateTime(2026, 7),
          pickupAddress: const {'label': 'Paris'},
          deliveryAddress: const {'label': 'Dakar'},
          paymentMethod: PaymentMethod.stripe,
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
      verify: (_) => verify(
        () => repo.createDedicatedTrip(
          't-1',
          departureDate: DateTime(2026, 7),
          pickupAddress: const {'label': 'Paris'},
          deliveryAddress: const {'label': 'Dakar'},
          paymentMethod: PaymentMethod.stripe,
        ),
      ).called(1),
    );
  });

  // ── NegotiationChangeTripRequested ──────────────────────────────────────────

  group('NegotiationChangeTripRequested', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'calls repository.changeTrip and emits [Loading, Loaded]',
      build: () {
        when(
          () => repo.changeTrip('thread-1', travelerAnnouncementId: 'ann-2'),
        ).thenAnswer((_) async => _fakeThread());
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(
        const NegotiationChangeTripRequested(
          threadId: 'thread-1',
          travelerAnnouncementId: 'ann-2',
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
      verify: (_) => verify(
        () => repo.changeTrip('thread-1', travelerAnnouncementId: 'ann-2'),
      ).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'from Loaded emits [ActionInProgress, Loaded]',
      build: () {
        when(
          () => repo.changeTrip(
            any(),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
          ),
        ).thenAnswer((_) async => _fakeThread());
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (bloc) => bloc.add(
        const NegotiationChangeTripRequested(
          threadId: 't-1',
          travelerAnnouncementId: 'ann-2',
        ),
      ),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationLoaded>(),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'emits [Loading, Error] when changeTrip throws',
      build: () {
        when(
          () => repo.changeTrip(
            any(),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
          ),
        ).thenThrow(Exception('server error'));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(
        const NegotiationChangeTripRequested(
          threadId: 't-1',
          travelerAnnouncementId: 'ann-2',
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationError>()],
    );
  });

  group('checkout — course avec le webhook Stripe', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'checkout 409 thread/not-awaiting-payment → recharge le thread et émet '
      'Loaded (paiement déjà finalisé par le webhook, pas d\'erreur)',
      build: () {
        when(
          () => repo.checkout(
            't-1',
            paymentIntentId: 'pi_1',
            paymentMethod: PaymentMethod.stripe,
          ),
        ).thenThrow(const ConflictException('thread/not-awaiting-payment'));
        when(() => repo.getById('t-1')).thenAnswer(
          (_) async => _fakeThread(status: NegotiationThreadStatus.accepted),
        );
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(
        const NegotiationCheckoutRequested(
          threadId: 't-1',
          paymentIntentId: 'pi_1',
          paymentMethod: PaymentMethod.stripe,
        ),
      ),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationLoaded>().having(
          (s) => s.thread.status,
          'status',
          NegotiationThreadStatus.accepted,
        ),
      ],
      verify: (_) => verify(() => repo.getById('t-1')).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'checkout succès → Loaded',
      build: () {
        when(
          () => repo.checkout(
            't-1',
            paymentIntentId: 'pi_1',
            paymentMethod: PaymentMethod.stripe,
          ),
        ).thenAnswer(
          (_) async => _fakeThread(status: NegotiationThreadStatus.accepted),
        );
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(
        const NegotiationCheckoutRequested(
          threadId: 't-1',
          paymentIntentId: 'pi_1',
          paymentMethod: PaymentMethod.stripe,
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'checkout autre conflit → NegotiationError (erreur réelle non avalée)',
      build: () {
        when(
          () => repo.checkout(
            't-1',
            paymentIntentId: 'pi_1',
            paymentMethod: PaymentMethod.stripe,
          ),
        ).thenThrow(const ConflictException('payment-method/not-accepted'));
        return _makeBloc(repo);
      },
      act: (bloc) => bloc.add(
        const NegotiationCheckoutRequested(
          threadId: 't-1',
          paymentIntentId: 'pi_1',
          paymentMethod: PaymentMethod.stripe,
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationError>()],
      verify: (_) => verifyNever(() => repo.getById(any())),
    );
  });

  // ── NegotiationSettleCommissionRequested ────────────────────────────────────

  group('NegotiationSettleCommissionRequested', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'garde anti double-débit : un règlement déjà en cours '
      '(ActionInProgress) ignore un second event, aucun appel réseau',
      build: () => _makeBloc(repo),
      seed: () => NegotiationActionInProgress(_fakeThread()),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [],
      verify: (_) => verifyNever(
        () => repo.settleCommission(
          any(),
          commissionSource: any(named: 'commissionSource'),
        ),
      ),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'règlement accepté → ActionInProgress puis NegotiationCommissionSettled',
      build: () {
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
          ),
        ).thenAnswer(
          (_) async =>
              const AcceptanceResponse(status: AcceptanceStatus.accepted),
        );
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationCommissionSettled>().having(
          (s) => s.threadId,
          'threadId',
          't-1',
        ),
      ],
      verify: (_) => verify(() => repo.settleCommission('t-1')).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'defaults to WALLET_FIRST from a state other than Loaded → Loading '
      'puis NegotiationCommissionSettled',
      build: () {
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
          ),
        ).thenAnswer(
          (_) async =>
              const AcceptanceResponse(status: AcceptanceStatus.accepted),
        );
        return _makeBloc(repo);
      },
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationCommissionSettled>(),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'useCard: true envoie commissionSource CARD au repository',
      build: () {
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
          ),
        ).thenAnswer(
          (_) async =>
              const AcceptanceResponse(status: AcceptanceStatus.accepted),
        );
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(
        const NegotiationSettleCommissionRequested('t-1', useCard: true),
      ),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationCommissionSettled>(),
      ],
      verify: (_) => verify(
        () => repo.settleCommission('t-1', commissionSource: 'CARD'),
      ).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'solde insuffisant → état porteur des montants, pas une erreur',
      build: () {
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
          ),
        ).thenAnswer(
          (_) async => const AcceptanceResponse(
            status: AcceptanceStatus.insufficientWallet,
            availableBalance: 1.0,
            requiredCommission: 5.0,
            hasCard: true,
            currency: 'EUR',
          ),
        );
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationCommissionInsufficientWallet>()
            .having((s) => s.availableBalance, 'availableBalance', 1.0)
            .having((s) => s.requiredCommission, 'requiredCommission', 5.0)
            .having((s) => s.hasCard, 'hasCard', true)
            .having((s) => s.currency, 'currency', 'EUR')
            .having((s) => s.threadId, 'threadId', 't-1'),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'échec (FAILED) → NegotiationError portant le message backend',
      build: () {
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
          ),
        ).thenAnswer(
          (_) async => const AcceptanceResponse(
            status: AcceptanceStatus.failed,
            error: 'Carte refusée',
          ),
        );
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>().having(
          (s) => s.error.message,
          'error.message',
          'Carte refusée',
        ),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'erreur réseau → NegotiationError',
      build: () {
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
          ),
        ).thenThrow(Exception('timeout'));
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>(),
      ],
    );

    // ── Chemin 3D Secure ──────────────────────────────────────────────────

    blocTest<NegotiationBloc, NegotiationState>(
      'requires3ds → handleNextAction réussi → confirmCommission accepté → '
      'NegotiationCommissionSettled',
      build: () {
        final stripe = _MockStripe();
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
          ),
        ).thenAnswer(
          (_) async => const AcceptanceResponse(
            status: AcceptanceStatus.requires3ds,
            clientSecret: 'pi_x',
          ),
        );
        when(
          () => stripe.handleNextAction('pi_x'),
        ).thenAnswer((_) async => _fakePaymentIntent());
        when(
          () => repo.confirmCommission('t-1'),
        ).thenAnswer((_) async => const ConfirmResponse(accepted: true));
        return _makeBloc(repo, stripe: stripe);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationCommissionSettled>().having(
          (s) => s.threadId,
          'threadId',
          't-1',
        ),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'requires3ds → confirmCommission refusé après 3DS → NegotiationError',
      build: () {
        final stripe = _MockStripe();
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
          ),
        ).thenAnswer(
          (_) async => const AcceptanceResponse(
            status: AcceptanceStatus.requires3ds,
            clientSecret: 'pi_x',
          ),
        );
        when(
          () => stripe.handleNextAction('pi_x'),
        ).thenAnswer((_) async => _fakePaymentIntent());
        when(() => repo.confirmCommission('t-1')).thenAnswer(
          (_) async =>
              const ConfirmResponse(accepted: false, error: 'Carte refusée'),
        );
        return _makeBloc(repo, stripe: stripe);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>().having(
          (s) => s.error.message,
          'error.message',
          'Carte refusée',
        ),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'requires3ds → StripeException (authentification interrompue) → '
      'NegotiationError',
      build: () {
        final stripe = _MockStripe();
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
          ),
        ).thenAnswer(
          (_) async => const AcceptanceResponse(
            status: AcceptanceStatus.requires3ds,
            clientSecret: 'pi_x',
          ),
        );
        when(() => stripe.handleNextAction('pi_x')).thenThrow(
          const StripeException(
            error: LocalizedErrorMessage(code: FailureCode.Canceled),
          ),
        );
        return _makeBloc(repo, stripe: stripe);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>().having(
          (s) => s.error.code,
          'error.code',
          'commission/3ds-interrupted',
        ),
      ],
      verify: (_) => verifyNever(() => repo.confirmCommission(any())),
    );
  });

  // ── NegotiationDeclineCommissionRequested ───────────────────────────────────

  group('NegotiationDeclineCommissionRequested', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'garde anti double-débit : un renoncement déjà en cours '
      '(ActionInProgress) ignore un second event, aucun appel réseau',
      build: () => _makeBloc(repo),
      seed: () => NegotiationActionInProgress(_fakeThread()),
      act: (b) => b.add(const NegotiationDeclineCommissionRequested('t-1')),
      expect: () => [],
      verify: (_) => verifyNever(() => repo.declineCommission(any())),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'renoncement réussi → ActionInProgress puis NegotiationCommissionDeclined,'
      ' la demande est libérée',
      build: () {
        when(() => repo.declineCommission('t-1')).thenAnswer((_) async {});
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(const NegotiationDeclineCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationCommissionDeclined>().having(
          (s) => s.threadId,
          'threadId',
          't-1',
        ),
      ],
      verify: (_) => verify(() => repo.declineCommission('t-1')).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'renoncement depuis un état autre que Loaded → Loading puis '
      'NegotiationCommissionDeclined',
      build: () {
        when(() => repo.declineCommission('t-1')).thenAnswer((_) async {});
        return _makeBloc(repo);
      },
      act: (b) => b.add(const NegotiationDeclineCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationLoading>(),
        isA<NegotiationCommissionDeclined>(),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'renoncement en échec → NegotiationError',
      build: () {
        when(
          () => repo.declineCommission('t-1'),
        ).thenThrow(Exception('server error'));
        return _makeBloc(repo);
      },
      seed: () => NegotiationLoaded(_fakeThread()),
      act: (b) => b.add(const NegotiationDeclineCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>(),
      ],
    );
  });
}
