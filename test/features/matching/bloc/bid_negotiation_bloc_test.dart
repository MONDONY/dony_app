import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements BidNegotiationRepository {}

BidNegotiation _thread({
  String bidId = 'bid1',
  String status = 'NEGOTIATING',
  int round = 1,
  bool canCounter = true,
  double? netEur,
  List<BidCustomItem> customItems = const [],
}) => BidNegotiation(
  bidId: bidId,
  announcementId: 'ann1',
  status: status,
  // Le serveur dit le rôle ; on le fait suivre le net pour garder leur sens
  // aux appels qui passent `netEur` afin de simuler la vue voyageur.
  role: netEur != null ? 'TRAVELER' : 'SENDER',
  round: round,
  maxRounds: 6,
  canCounter: canCounter,
  proposedGrossEur: 42,
  netEur: netEur,
  customItems: customItems,
);

void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    registerFallbackValue(BidPaymentMethod.stripe);
  });

  setUp(() {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  BidNegotiationBloc buildBloc({bool enabled = true}) {
    final analytics = enabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return BidNegotiationBloc(repo, analytics);
  }

  void stubPropose(BidNegotiation result) {
    when(
      () => repo.propose(
        announcementId: any(named: 'announcementId'),
        weightKg: any(named: 'weightKg'),
        description: any(named: 'description'),
        contentCategory: any(named: 'contentCategory'),
        recipientName: any(named: 'recipientName'),
        recipientPhone: any(named: 'recipientPhone'),
        proposedTotalEur: any(named: 'proposedTotalEur'),
        paymentMethod: any(named: 'paymentMethod'),
        phoneNumber: any(named: 'phoneNumber'),
        countryCode: any(named: 'countryCode'),
        photoKeys: any(named: 'photoKeys'),
        customItems: any(named: 'customItems'),
        gridItems: any(named: 'gridItems'),
      ),
    ).thenAnswer((_) async => result);
  }

  void stubProposeThrows(Object error) {
    when(
      () => repo.propose(
        announcementId: any(named: 'announcementId'),
        weightKg: any(named: 'weightKg'),
        description: any(named: 'description'),
        contentCategory: any(named: 'contentCategory'),
        recipientName: any(named: 'recipientName'),
        recipientPhone: any(named: 'recipientPhone'),
        proposedTotalEur: any(named: 'proposedTotalEur'),
        paymentMethod: any(named: 'paymentMethod'),
        phoneNumber: any(named: 'phoneNumber'),
        countryCode: any(named: 'countryCode'),
        photoKeys: any(named: 'photoKeys'),
        customItems: any(named: 'customItems'),
        gridItems: any(named: 'gridItems'),
      ),
    ).thenThrow(error);
  }

  const proposeEvent = BidNegotiationProposeRequested(
    announcementId: 'ann1',
    weightKg: 3,
    description: 'Deux paires de chaussures',
    contentCategory: 'CLOTHING',
    recipientName: 'Awa Diop',
    recipientPhone: '+221700000000',
    proposedTotalEur: 42,
  );

  group('fetch', () {
    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'fetch reussi emet Loading puis Loaded',
      build: () {
        when(() => repo.thread('bid1')).thenAnswer((_) async => _thread());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationFetchRequested('bid1')),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationLoaded>()
            .having((s) => s.negotiation.bidId, 'bidId', 'bid1')
            .having((s) => s.action, 'action', BidNegotiationAction.fetched),
      ],
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'fetch en erreur emet Loading puis Error',
      build: () {
        when(() => repo.thread('bid1')).thenThrow(const OfflineException());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationFetchRequested('bid1')),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationError>().having(
          (s) => s.error.code,
          'code',
          'OFFLINE',
        ),
      ],
    );
  });

  group('propose', () {
    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'propose reussi emet Loading puis Loaded et tire trip_negotiation_proposed',
      build: () {
        stubPropose(_thread());
        return buildBloc();
      },
      act: (bloc) => bloc.add(proposeEvent),
      wait: const Duration(milliseconds: 1),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationLoaded>().having(
          (s) => s.action,
          'action',
          BidNegotiationAction.proposed,
        ),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.tripNegotiationProposed, any()),
        ).called(1);
      },
    );

    test(
      'les proprietes de trip_negotiation_proposed ne portent aucune PII',
      () async {
        stubPropose(_thread());
        final bloc = buildBloc();
        bloc.add(proposeEvent);
        await bloc.stream.firstWhere((s) => s is BidNegotiationLoaded);
        await Future<void>.delayed(Duration.zero);

        final captured =
            verify(
                  () => backend.capture(
                    AnalyticsEvents.tripNegotiationProposed,
                    captureAny(),
                  ),
                ).captured.single
                as Map<String, Object?>;

        final flat = captured.entries
            .map((e) => '${e.key}=${e.value}')
            .join('|');
        expect(flat, isNot(contains('Awa')));
        expect(flat, isNot(contains('Diop')));
        expect(flat, isNot(contains('+221700000000')));
        expect(flat, isNot(contains('chaussures')));
        expect(captured['announcement_id'], 'ann1');
      },
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      '422 announcement-not-negotiable donne une erreur portant le code',
      build: () {
        stubProposeThrows(
          const ValidationException(
            'Trajet non negociable',
            code: 'announcement-not-negotiable',
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(proposeEvent),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationError>().having(
          (s) => s.error.code,
          'code',
          'announcement-not-negotiable',
        ),
      ],
      verify: (_) {
        verifyNever(() => backend.capture(any(), any()));
      },
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      '409 already-bid donne une erreur portant le code',
      build: () {
        stubProposeThrows(
          const ConflictException('Deja propose', code: 'already-bid'),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(proposeEvent),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationError>().having(
          (s) => s.error.code,
          'code',
          'already-bid',
        ),
      ],
    );
  });

  group('counter', () {
    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'counter cote expediteur tire trip_negotiation_countered avec actor sender',
      build: () {
        when(
          () => repo.counter(
            'bid1',
            proposedTotalEur: any(named: 'proposedTotalEur'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => _thread(round: 2));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const BidNegotiationCounterRequested('bid1', proposedTotalEur: 38),
      ),
      wait: const Duration(milliseconds: 1),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationLoaded>().having(
          (s) => s.action,
          'action',
          BidNegotiationAction.countered,
        ),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.tripNegotiationCountered, {
            'bid_id': 'bid1',
            'round': 2,
            'actor': 'sender',
          }),
        ).called(1);
      },
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'counter cote voyageur porte actor traveler',
      build: () {
        when(
          () => repo.counter(
            'bid1',
            proposedTotalEur: any(named: 'proposedTotalEur'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => _thread(round: 3, netEur: 30));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const BidNegotiationCounterRequested('bid1', proposedTotalEur: 38),
      ),
      wait: const Duration(milliseconds: 1),
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.tripNegotiationCountered, {
            'bid_id': 'bid1',
            'round': 3,
            'actor': 'traveler',
          }),
        ).called(1);
      },
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      '409 not-your-turn donne une erreur sans event analytics',
      build: () {
        when(
          () => repo.counter(
            'bid1',
            proposedTotalEur: any(named: 'proposedTotalEur'),
            body: any(named: 'body'),
          ),
        ).thenThrow(
          const ConflictException('Pas votre tour', code: 'not-your-turn'),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const BidNegotiationCounterRequested('bid1', proposedTotalEur: 38),
      ),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationError>().having(
          (s) => s.error.code,
          'code',
          'not-your-turn',
        ),
      ],
      verify: (_) {
        verifyNever(() => backend.capture(any(), any()));
      },
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'une erreur garde le fil deja charge pour que l ecran reste affichable',
      build: () {
        when(() => repo.thread('bid1')).thenAnswer((_) async => _thread());
        when(
          () => repo.counter(
            'bid1',
            proposedTotalEur: any(named: 'proposedTotalEur'),
            body: any(named: 'body'),
          ),
        ).thenThrow(
          const ConflictException('Ferme', code: 'negotiation-closed'),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const BidNegotiationFetchRequested('bid1'));
        await bloc.stream.firstWhere((s) => s is BidNegotiationLoaded);
        bloc.add(
          const BidNegotiationCounterRequested('bid1', proposedTotalEur: 38),
        );
      },
      skip: 3,
      expect: () => [
        isA<BidNegotiationError>().having(
          (s) => s.negotiation?.bidId,
          'negotiation conservee',
          'bid1',
        ),
      ],
    );
  });

  group('accept, reject, cancel', () {
    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'accept tire trip_negotiation_accepted',
      build: () {
        when(
          () => repo.accept('bid1'),
        ).thenAnswer((_) async => _thread(status: 'ACCEPTED', round: 2));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationAcceptRequested('bid1')),
      wait: const Duration(milliseconds: 1),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationLoaded>().having(
          (s) => s.action,
          'action',
          BidNegotiationAction.accepted,
        ),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.tripNegotiationAccepted, {
            'bid_id': 'bid1',
            'round': 2,
            'actor': 'sender',
          }),
        ).called(1);
      },
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'reject tire trip_negotiation_rejected',
      build: () {
        when(
          () => repo.reject('bid1'),
        ).thenAnswer((_) async => _thread(status: 'REJECTED', round: 2));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationRejectRequested('bid1')),
      wait: const Duration(milliseconds: 1),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationLoaded>().having(
          (s) => s.action,
          'action',
          BidNegotiationAction.rejected,
        ),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.tripNegotiationRejected, any()),
        ).called(1);
      },
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'cancel emet Loaded sans event dedie',
      build: () {
        when(
          () => repo.cancel('bid1'),
        ).thenAnswer((_) async => _thread(status: 'CANCELLED'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationCancelRequested('bid1')),
      wait: const Duration(milliseconds: 1),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationLoaded>().having(
          (s) => s.action,
          'action',
          BidNegotiationAction.cancelled,
        ),
      ],
    );
  });

  group('read', () {
    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'read n emet aucun etat et appelle le repository',
      build: () {
        when(() => repo.markRead('bid1')).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationReadRequested('bid1')),
      expect: () => <BidNegotiationState>[],
      verify: (_) {
        verify(() => repo.markRead('bid1')).called(1);
      },
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'un echec de read reste silencieux',
      build: () {
        when(() => repo.markRead('bid1')).thenThrow(const OfflineException());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationReadRequested('bid1')),
      expect: () => <BidNegotiationState>[],
    );
  });

  group('checkout', () {
    BidCheckoutResponseModel checkout() => BidCheckoutResponseModel(
      bidId: 'bid1',
      clientSecret: 'pi_1_secret_2',
      publishableKey: 'pk_test_1',
      expiresAt: DateTime(2026, 8, 19, 4, 12),
      currency: 'eur',
      paymentMethodTypes: const ['card', 'paypal'],
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'checkout reussi emet CheckoutReady et tire l event de paiement',
      build: () {
        when(
          () => repo.negotiationCheckout('bid1'),
        ).thenAnswer((_) async => checkout());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationCheckoutRequested('bid1')),
      wait: const Duration(milliseconds: 1),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationCheckoutReady>()
            .having(
              (s) => s.checkout.clientSecret,
              'clientSecret',
              'pi_1_secret_2',
            )
            .having((s) => s.checkout.bidId, 'bidId', 'bid1'),
      ],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.tripNegotiationPaymentStarted, {
            'bid_id': 'bid1',
          }),
        ).called(1);
      },
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'le fil deja charge est conserve dans l etat de checkout',
      build: () {
        when(
          () => repo.thread('bid1'),
        ).thenAnswer((_) async => _thread(status: 'AWAITING_PAYMENT'));
        when(
          () => repo.negotiationCheckout('bid1'),
        ).thenAnswer((_) async => checkout());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const BidNegotiationFetchRequested('bid1'));
        await Future<void>.delayed(const Duration(milliseconds: 1));
        bloc.add(const BidNegotiationCheckoutRequested('bid1'));
      },
      wait: const Duration(milliseconds: 5),
      skip: 2,
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationCheckoutReady>().having(
          (s) => s.negotiation?.status,
          'status du fil conserve',
          'AWAITING_PAYMENT',
        ),
      ],
    );

    for (final entry in const {
      'bid-not-negotiated': 409,
      'bid-not-awaiting-payment': 409,
      'payment-already-completed': 409,
      'traveler-stripe-invalid': 422,
    }.entries) {
      blocTest<BidNegotiationBloc, BidNegotiationState>(
        '${entry.value} ${entry.key} donne une erreur portant le code, '
        'sans event analytics',
        build: () {
          when(() => repo.negotiationCheckout('bid1')).thenThrow(
            entry.value == 409
                ? ConflictException('refus', code: entry.key)
                : ValidationException('refus', code: entry.key),
          );
          return buildBloc();
        },
        act: (bloc) => bloc.add(const BidNegotiationCheckoutRequested('bid1')),
        wait: const Duration(milliseconds: 1),
        expect: () => [
          isA<BidNegotiationLoading>(),
          isA<BidNegotiationError>().having(
            (s) => s.error.code,
            'code',
            entry.key,
          ),
        ],
        verify: (_) {
          verifyNever(() => backend.capture(any(), any()));
        },
      );
    }

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      '404 bid-not-found et 403 forbidden remontent aussi leur code',
      build: () {
        when(() => repo.negotiationCheckout('bid1')).thenThrow(
          const NotFoundException(
            message: 'introuvable',
            apiCode: 'bid-not-found',
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationCheckoutRequested('bid1')),
      wait: const Duration(milliseconds: 1),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationError>().having(
          (s) => s.error.code,
          'code',
          'bid-not-found',
        ),
      ],
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'un double tap rejoue le checkout, idempotent cote serveur',
      build: () {
        when(
          () => repo.negotiationCheckout('bid1'),
        ).thenAnswer((_) async => checkout());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const BidNegotiationCheckoutRequested('bid1'));
        await Future<void>.delayed(const Duration(milliseconds: 1));
        bloc.add(const BidNegotiationCheckoutRequested('bid1'));
      },
      wait: const Duration(milliseconds: 5),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationCheckoutReady>(),
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationCheckoutReady>(),
      ],
      verify: (_) {
        verify(() => repo.negotiationCheckout('bid1')).called(2);
      },
    );
  });
}
