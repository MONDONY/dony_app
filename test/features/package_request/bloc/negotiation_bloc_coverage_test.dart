import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements NegotiationRepository {}

NegotiationThread _thread({
  String id = 't-1',
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  String? commissionStatus,
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
  messages: const [],
  commissionStatus: commissionStatus,
);

DedicatedTripPayload _payload({
  String? description,
  bool useCard = false,
  List<String>? accepted,
}) => DedicatedTripPayload(
  departureDate: DateTime(2026, 7, 1, 14, 30),
  departureTime: '10:00',
  arrivalTime: '18:00',
  arrivalDate: '2026-07-02',
  pickupAddress: const {'city': 'Paris'},
  deliveryAddress: const {'city': 'Dakar'},
  description: description,
  acceptedContentTypes: accepted,
  refusedTypes: const ['LIQUID'],
  useCardForCommission: useCard,
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

  NegotiationBloc build() {
    final analytics = makeEnabledAnalytics(backend)..onConfigured();
    return NegotiationBloc(repo, analytics: analytics);
  }

  group('événements — égalité Equatable', () {
    test('NegotiationStartRequested : mêmes champs égaux, prix différent '
        'différent', () {
      NegotiationStartRequested make(double price) => NegotiationStartRequested(
        packageRequestId: 'pr-1',
        proposedPriceEur: price,
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        travelerAnnouncementId: 'a-1',
        body: 'Bonjour',
        isFirmPrice: true,
        createDedicatedTrip: true,
        dedicatedTripPayload: const {'k': 'v'},
      );
      expect(make(30), make(30));
      expect(make(30), isNot(make(31)));
    });

    test('DedicatedTripPayload : égalité et toJson complet', () {
      expect(_payload(description: 'd'), _payload(description: 'd'));
      expect(_payload(useCard: true), isNot(_payload()));
      final json = _payload(
        description: 'Fragile',
        accepted: ['DOCS'],
      ).toJson();
      expect(json, {
        'departureDate': '2026-07-01',
        'departureTime': '10:00',
        'arrivalTime': '18:00',
        'arrivalDate': '2026-07-02',
        'pickupAddress': {'city': 'Paris'},
        'deliveryAddress': {'city': 'Dakar'},
        'description': 'Fragile',
        'acceptedContentTypes': ['DOCS'],
        'refusedTypes': ['LIQUID'],
        'useCardForCommission': false,
      });
    });

    test('DedicatedTripPayload.toJson omet les champs optionnels nuls', () {
      final json = DedicatedTripPayload(
        departureDate: DateTime(2026, 7, 2),
        pickupAddress: const {},
        deliveryAddress: const {},
      ).toJson();
      expect(json.keys, [
        'departureDate',
        'pickupAddress',
        'deliveryAddress',
        'useCardForCommission',
      ]);
    });

    test('NegotiationStartWithDedicatedTripRequested : égalité par champ', () {
      NegotiationStartWithDedicatedTripRequested make({bool firm = false}) =>
          NegotiationStartWithDedicatedTripRequested(
            packageRequestId: 'pr-1',
            proposedPriceEur: 30,
            travelerTravelDate: DateTime(2026, 6, 15),
            travelerAvailableKg: 10,
            dedicatedTrip: _payload(),
            body: 'b',
            isFirmPrice: firm,
          );
      expect(make(), make());
      expect(make(), isNot(make(firm: true)));
    });

    test('NegotiationCreateDedicatedTripRequested : égalité par champ', () {
      NegotiationCreateDedicatedTripRequested make(PaymentMethod m) =>
          NegotiationCreateDedicatedTripRequested(
            threadId: 't-1',
            departureDate: DateTime(2026, 7, 2),
            departureTime: '10:00',
            arrivalTime: '12:00',
            arrivalDate: '2026-07-01',
            pickupAddress: const {'city': 'Lyon'},
            deliveryAddress: const {'city': 'Bamako'},
            description: 'x',
            acceptedContentTypes: const ['DOCS'],
            refusedTypes: const ['LIQUID'],
            paymentMethod: m,
            useCardForCommission: true,
          );
      expect(make(PaymentMethod.stripe), make(PaymentMethod.stripe));
      expect(make(PaymentMethod.stripe), isNot(make(PaymentMethod.cash)));
    });

    test('événements simples : égalité sur threadId et champs', () {
      expect(
        const NegotiationFetchRequested('a'),
        const NegotiationFetchRequested('a'),
      );
      expect(
        const NegotiationNudgeRequested('a'),
        isNot(const NegotiationNudgeRequested('b')),
      );
      expect(
        const NegotiationCounterRequested(threadId: 't', proposedPriceEur: 1),
        isNot(
          const NegotiationCounterRequested(threadId: 't', proposedPriceEur: 2),
        ),
      );
      expect(
        const NegotiationAcceptRequested(threadId: 't', body: 'ok'),
        isNot(const NegotiationAcceptRequested(threadId: 't', body: 'ko')),
      );
      expect(
        const NegotiationRejectRequested(threadId: 't', reason: 'a'),
        isNot(const NegotiationRejectRequested(threadId: 't', reason: 'b')),
      );
      expect(
        const NegotiationCancelRequested(threadId: 't'),
        const NegotiationCancelRequested(threadId: 't'),
      );
      expect(
        const NegotiationSubmitTripRequested(
          threadId: 't',
          travelerAnnouncementId: 'a',
          paymentMethod: PaymentMethod.cash,
        ),
        isNot(
          const NegotiationSubmitTripRequested(
            threadId: 't',
            travelerAnnouncementId: 'a',
            paymentMethod: PaymentMethod.cash,
            useCardForCommission: true,
          ),
        ),
      );
      expect(
        const NegotiationCheckoutRequested(
          threadId: 't',
          paymentIntentId: 'pi_1',
        ),
        isNot(
          const NegotiationCheckoutRequested(
            threadId: 't',
            paymentIntentId: 'pi_2',
          ),
        ),
      );
      expect(
        const NegotiationRefuseTripRequested(threadId: 't', reason: 'r'),
        isNot(const NegotiationRefuseTripRequested(threadId: 't', reason: 's')),
      );
      expect(
        const NegotiationChangeTripRequested(
          threadId: 't',
          travelerAnnouncementId: 'a',
        ),
        isNot(
          const NegotiationChangeTripRequested(
            threadId: 't',
            travelerAnnouncementId: 'b',
          ),
        ),
      );
      expect(
        const NegotiationSettleCommissionRequested('t', fundingCurrency: 'XOF'),
        isNot(const NegotiationSettleCommissionRequested('t', useCard: true)),
      );
      expect(
        const NegotiationDeclineCommissionRequested('t'),
        const NegotiationDeclineCommissionRequested('t'),
      );
      expect(
        const NegotiationCancelDepositRequested('t'),
        isNot(const NegotiationCancelDepositRequested('u')),
      );
    });
  });

  group('branches d’erreur et de chargement', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'fetch en échec → Loading puis Error',
      build: () {
        when(
          () => repo.getById('t-1'),
        ).thenThrow(const NotFoundException(message: 'absent'));
        return build();
      },
      act: (b) => b.add(const NegotiationFetchRequested('t-1')),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationError>()],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'start en échec → Error, aucun événement analytics',
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
        ).thenThrow(const ServerException());
        return build();
      },
      act: (b) => b.add(
        NegotiationStartRequested(
          packageRequestId: 'pr-1',
          proposedPriceEur: 30,
          travelerTravelDate: DateTime(2026, 6, 15),
          travelerAvailableKg: 10,
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationError>()],
      verify: (_) => verifyNever(() => backend.capture(any(), any())),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'start avec trajet dédié à prix ferme → firm_price_taken et payload '
      'sérialisé transmis',
      build: () {
        when(
          () => repo.start(
            packageRequestId: any(named: 'packageRequestId'),
            proposedPriceEur: any(named: 'proposedPriceEur'),
            travelerTravelDate: any(named: 'travelerTravelDate'),
            travelerAvailableKg: any(named: 'travelerAvailableKg'),
            body: any(named: 'body'),
            createDedicatedTrip: any(named: 'createDedicatedTrip'),
            dedicatedTripPayload: any(named: 'dedicatedTripPayload'),
          ),
        ).thenAnswer((_) async => _thread());
        return build();
      },
      act: (b) => b.add(
        NegotiationStartWithDedicatedTripRequested(
          packageRequestId: 'pr-1',
          proposedPriceEur: 120,
          travelerTravelDate: DateTime(2026, 6, 15),
          travelerAvailableKg: 10,
          dedicatedTrip: _payload(),
          isFirmPrice: true,
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
      verify: (_) {
        verify(
          () => repo.start(
            packageRequestId: 'pr-1',
            proposedPriceEur: 120,
            travelerTravelDate: DateTime(2026, 6, 15),
            travelerAvailableKg: 10,
            createDedicatedTrip: true,
            dedicatedTripPayload: _payload().toJson(),
          ),
        ).called(1);
        verify(
          () => backend.capture(AnalyticsEvents.firmPriceTaken, {
            'request_id': 'pr-1',
          }),
        ).called(1);
      },
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'start avec trajet dédié en échec → Error',
      build: () {
        when(
          () => repo.start(
            packageRequestId: any(named: 'packageRequestId'),
            proposedPriceEur: any(named: 'proposedPriceEur'),
            travelerTravelDate: any(named: 'travelerTravelDate'),
            travelerAvailableKg: any(named: 'travelerAvailableKg'),
            body: any(named: 'body'),
            createDedicatedTrip: any(named: 'createDedicatedTrip'),
            dedicatedTripPayload: any(named: 'dedicatedTripPayload'),
          ),
        ).thenThrow(const ServerException());
        return build();
      },
      act: (b) => b.add(
        NegotiationStartWithDedicatedTripRequested(
          packageRequestId: 'pr-1',
          proposedPriceEur: 10,
          travelerTravelDate: DateTime(2026, 6, 15),
          travelerAvailableKg: 10,
          dedicatedTrip: _payload(),
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationError>()],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'contre-offre hors fil chargé → Loading puis Loaded, tranche 50-100',
      build: () {
        when(
          () => repo.counter(
            't-1',
            proposedPriceEur: 60,
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => _thread());
        return build();
      },
      act: (b) => b.add(
        const NegotiationCounterRequested(
          threadId: 't-1',
          proposedPriceEur: 60,
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
      verify: (_) => verify(
        () => backend.capture(
          AnalyticsEvents.negotiationOfferMade,
          any(that: containsPair('amount_bracket', '50-100')),
        ),
      ).called(1),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'contre-offre en échec → Error',
      build: () {
        when(
          () => repo.counter(
            any(),
            proposedPriceEur: any(named: 'proposedPriceEur'),
            body: any(named: 'body'),
          ),
        ).thenThrow(const ServerException());
        return build();
      },
      seed: () => NegotiationLoaded(_thread()),
      act: (b) => b.add(
        const NegotiationCounterRequested(threadId: 't-1', proposedPriceEur: 5),
      ),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>(),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'acceptation hors fil chargé → Loading puis Loaded',
      build: () {
        when(
          () => repo.accept('t-1', body: any(named: 'body')),
        ).thenAnswer((_) async => _thread());
        return build();
      },
      act: (b) => b.add(const NegotiationAcceptRequested(threadId: 't-1')),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'acceptation en échec → Error',
      build: () {
        when(
          () => repo.accept(any(), body: any(named: 'body')),
        ).thenThrow(const ServerException());
        return build();
      },
      seed: () => NegotiationLoaded(_thread()),
      act: (b) => b.add(const NegotiationAcceptRequested(threadId: 't-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>(),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'refus hors fil chargé → Loading puis Rejected',
      build: () {
        when(() => repo.reject('t-1', reason: 'cher')).thenAnswer((_) async {});
        return build();
      },
      act: (b) => b.add(
        const NegotiationRejectRequested(threadId: 't-1', reason: 'cher'),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationRejected>()],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'refus en échec → Error',
      build: () {
        when(
          () => repo.reject(any(), reason: any(named: 'reason')),
        ).thenThrow(const ServerException());
        return build();
      },
      seed: () => NegotiationLoaded(_thread()),
      act: (b) => b.add(const NegotiationRejectRequested(threadId: 't-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>(),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'checkout hors fil chargé → Loading puis Loaded',
      build: () {
        when(
          () => repo.checkout(
            't-1',
            paymentIntentId: 'cash',
            paymentMethod: any(named: 'paymentMethod'),
          ),
        ).thenAnswer((_) async => _thread());
        return build();
      },
      act: (b) => b.add(
        const NegotiationCheckoutRequested(
          threadId: 't-1',
          paymentIntentId: 'cash',
        ),
      ),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
      verify: (_) => verifyNever(
        () => backend.capture(AnalyticsEvents.paymentSucceeded, any()),
      ),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'refus du trajet hors fil chargé → Loading puis Loaded',
      build: () {
        when(
          () => repo.refuseTrip('t-1', reason: any(named: 'reason')),
        ).thenAnswer((_) async => _thread());
        return build();
      },
      act: (b) => b.add(const NegotiationRefuseTripRequested(threadId: 't-1')),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationLoaded>()],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'relance hors fil chargé → Loading puis NudgeSent',
      build: () {
        when(() => repo.nudge('t-1')).thenAnswer((_) async => _thread());
        return build();
      },
      act: (b) => b.add(const NegotiationNudgeRequested('t-1')),
      expect: () => [isA<NegotiationLoading>(), isA<NegotiationNudgeSent>()],
      verify: (_) => verify(
        () => backend.capture(AnalyticsEvents.negotiationNudgeSent, any()),
      ).called(1),
    );
  });

  group('actions depuis un fil chargé → ActionInProgress puis Error', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'rattachement de trajet en échec',
      build: () {
        when(
          () => repo.submitTrip(
            any(),
            travelerAnnouncementId: any(named: 'travelerAnnouncementId'),
            paymentMethod: any(named: 'paymentMethod'),
            useCardForCommission: any(named: 'useCardForCommission'),
          ),
        ).thenThrow(const ServerException());
        return build();
      },
      seed: () => NegotiationLoaded(_thread()),
      act: (b) => b.add(
        const NegotiationSubmitTripRequested(
          threadId: 't-1',
          travelerAnnouncementId: 'a-1',
          paymentMethod: PaymentMethod.stripe,
        ),
      ),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>(),
      ],
      verify: (_) => verifyNever(
        () => backend.capture(AnalyticsEvents.tripLinkPaymentBlocked, any()),
      ),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'création de trajet dédié en échec',
      build: () {
        when(
          () => repo.createDedicatedTrip(
            any(),
            departureDate: any(named: 'departureDate'),
            departureTime: any(named: 'departureTime'),
            arrivalTime: any(named: 'arrivalTime'),
            arrivalDate: any(named: 'arrivalDate'),
            pickupAddress: any(named: 'pickupAddress'),
            deliveryAddress: any(named: 'deliveryAddress'),
            description: any(named: 'description'),
            acceptedContentTypes: any(named: 'acceptedContentTypes'),
            refusedTypes: any(named: 'refusedTypes'),
            paymentMethod: any(named: 'paymentMethod'),
            useCardForCommission: any(named: 'useCardForCommission'),
          ),
        ).thenThrow(const ServerException());
        return build();
      },
      seed: () => NegotiationLoaded(_thread()),
      act: (b) => b.add(
        NegotiationCreateDedicatedTripRequested(
          threadId: 't-1',
          departureDate: DateTime(2026, 7, 2),
          pickupAddress: const {},
          deliveryAddress: const {},
          paymentMethod: PaymentMethod.cash,
        ),
      ),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>(),
      ],
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'checkout en échec non lié au webhook',
      build: () {
        when(
          () => repo.checkout(
            any(),
            paymentIntentId: any(named: 'paymentIntentId'),
            paymentMethod: any(named: 'paymentMethod'),
          ),
        ).thenThrow(const ServerException());
        return build();
      },
      seed: () => NegotiationLoaded(_thread()),
      act: (b) => b.add(
        const NegotiationCheckoutRequested(
          threadId: 't-1',
          paymentIntentId: 'pi_1',
        ),
      ),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>(),
      ],
      verify: (_) => verifyNever(() => repo.getById(any())),
    );
  });

  group('règlement de commission', () {
    blocTest<NegotiationBloc, NegotiationState>(
      'reprise 3DS : confirmation acceptée → Settled sans nouveau règlement',
      build: () {
        when(
          () => repo.confirmCommission('t-1'),
        ).thenAnswer((_) async => const ConfirmResponse(accepted: true));
        return build();
      },
      seed: () => NegotiationLoaded(_thread(commissionStatus: 'REQUIRES_3DS')),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationCommissionSettled>(),
      ],
      verify: (_) => verifyNever(
        () => repo.settleCommission(
          any(),
          commissionSource: any(named: 'commissionSource'),
          fundingCurrency: any(named: 'fundingCurrency'),
        ),
      ),
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'course perdue (request/already-accepted) → Error puis fil rechargé',
      build: () {
        when(
          () => repo.settleCommission(
            any(),
            commissionSource: any(named: 'commissionSource'),
            fundingCurrency: any(named: 'fundingCurrency'),
          ),
        ).thenThrow(
          const ConflictException('pris', code: 'request/already-accepted'),
        );
        when(() => repo.getById('t-1')).thenAnswer(
          (_) async => _thread(status: NegotiationThreadStatus.rejected),
        );
        return build();
      },
      seed: () => NegotiationLoaded(_thread()),
      act: (b) => b.add(
        const NegotiationSettleCommissionRequested(
          't-1',
          fundingCurrency: 'XOF',
        ),
      ),
      expect: () => [
        isA<NegotiationActionInProgress>(),
        isA<NegotiationError>().having(
          (s) => s.error.code,
          'code',
          'request/already-accepted',
        ),
        isA<NegotiationLoading>(),
        isA<NegotiationLoaded>(),
      ],
      verify: (_) {
        verify(
          () => repo.settleCommission('t-1', fundingCurrency: 'XOF'),
        ).called(1);
        verify(
          () => backend.capture(
            AnalyticsEvents.commissionFundingCurrencyChosen,
            {'currency': 'XOF', 'context': 'negotiation'},
          ),
        ).called(1);
      },
    );
  });
}
