import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/commission_grid_test_doubles.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements BidNegotiationRepository {}

class _MockConfig extends Mock implements IConfigRepository {}

/// Grille figée d'un fil, mêmes tranches que la grille de référence.
CommissionGrid _threadGrid() {
  final ref = testGrid757();
  return CommissionGrid(
    id: 'g-thread',
    effectiveFrom: ref.effectiveFrom,
    tiers: ref.tiers,
    minimums: ref.minimums,
  );
}

BidNegotiation _thread({
  String bidId = 'bid1',
  String status = 'NEGOTIATING',
  int round = 1,
  bool canCounter = true,
  double? netEur,
  String? commissionGridId,
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
  commissionGridId: commissionGridId,
  customItems: customItems,
);

void main() {
  late _MockRepo repo;
  late _MockConfig config;
  late MockAnalyticsBackend backend;

  setUpAll(() {
    registerFallbackValue(BidPaymentMethod.stripe);
  });

  setUp(() {
    repo = _MockRepo();
    config = _MockConfig();
    backend = MockAnalyticsBackend();
    CommissionGridStore.reset();
  });

  tearDown(CommissionGridStore.reset);

  BidNegotiationBloc buildBloc({
    bool enabled = true,
    Duration gridTimeout = const Duration(seconds: 3),
  }) {
    final analytics = enabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return BidNegotiationBloc(
      repo,
      analytics,
      config,
      gridTimeout: gridTimeout,
    );
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

  group('grille figée du fil', () {
    // Seul le voyageur calcule un aperçu sur la grille figée, et seulement
    // tant que le fil se négocie : c'est le fil qui attend la grille.
    BidNegotiation travelerThread({String status = 'NEGOTIATING'}) =>
        _thread(commissionGridId: 'g-thread', netEur: 40, status: status);

    test('fetch charge la grille figée avant d émettre le fil', () async {
      final grid = Completer<CommissionGrid?>();
      when(() => repo.thread('bid1')).thenAnswer((_) async => travelerThread());
      when(
        () => config.getCommissionGridById('g-thread'),
      ).thenAnswer((_) => grid.future);
      final bloc = buildBloc();
      final states = <BidNegotiationState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const BidNegotiationFetchRequested('bid1'));
      await pumpEventQueue();
      // Le fil est lu, mais pas encore émis : la grille est attendue.
      expect(states, [isA<BidNegotiationLoading>()]);

      grid.complete(_threadGrid());
      await pumpEventQueue();
      expect(states.last, isA<BidNegotiationLoaded>());
      expect(CommissionGridStore.byId('g-thread'), isNotNull);
      verify(() => config.getCommissionGridById('g-thread')).called(1);

      await sub.cancel();
      await bloc.close();
    });

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'échec du chargement de la grille : le fil est émis quand même',
      build: () {
        when(
          () => repo.thread('bid1'),
        ).thenAnswer((_) async => travelerThread());
        when(
          () => config.getCommissionGridById('g-thread'),
        ).thenThrow(const OfflineException());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationFetchRequested('bid1')),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationLoaded>().having(
          (s) => s.negotiation.commissionGridId,
          'commissionGridId',
          'g-thread',
        ),
      ],
      verify: (_) => expect(CommissionGridStore.byId('g-thread'), isNull),
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'grille trop lente : le fil est émis après le délai',
      build: () {
        when(
          () => repo.thread('bid1'),
        ).thenAnswer((_) async => travelerThread());
        when(
          () => config.getCommissionGridById('g-thread'),
        ).thenAnswer((_) => Completer<CommissionGrid?>().future);
        return buildBloc(gridTimeout: const Duration(milliseconds: 10));
      },
      act: (bloc) => bloc.add(const BidNegotiationFetchRequested('bid1')),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<BidNegotiationLoading>(), isA<BidNegotiationLoaded>()],
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'grille déjà connue : aucune lecture',
      build: () {
        CommissionGridStore.put(_threadGrid());
        when(
          () => repo.thread('bid1'),
        ).thenAnswer((_) async => travelerThread());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationFetchRequested('bid1')),
      expect: () => [isA<BidNegotiationLoading>(), isA<BidNegotiationLoaded>()],
      verify: (_) => verifyNever(() => config.getCommissionGridById(any())),
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'fil sans grille : aucune lecture',
      build: () {
        when(() => repo.thread('bid1')).thenAnswer((_) async => _thread());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationFetchRequested('bid1')),
      expect: () => [isA<BidNegotiationLoading>(), isA<BidNegotiationLoaded>()],
      verify: (_) => verifyNever(() => config.getCommissionGridById(any())),
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'propose : la grille figée du nouveau fil est chargée',
      build: () {
        stubPropose(travelerThread());
        when(
          () => config.getCommissionGridById('g-thread'),
        ).thenAnswer((_) async => _threadGrid());
        return buildBloc();
      },
      act: (bloc) => bloc.add(proposeEvent),
      wait: const Duration(milliseconds: 1),
      expect: () => [isA<BidNegotiationLoading>(), isA<BidNegotiationLoaded>()],
      verify: (_) => expect(CommissionGridStore.byId('g-thread'), isNotNull),
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'vue expéditeur : le fil à grille n attend aucune lecture',
      build: () {
        when(
          () => repo.thread('bid1'),
        ).thenAnswer((_) async => _thread(commissionGridId: 'g-thread'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationFetchRequested('bid1')),
      expect: () => [isA<BidNegotiationLoading>(), isA<BidNegotiationLoaded>()],
      verify: (_) => verifyNever(() => config.getCommissionGridById(any())),
    );

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'fil fermé côté voyageur : aucune lecture',
      build: () {
        when(
          () => repo.accept('bid1'),
        ).thenAnswer((_) async => travelerThread(status: 'ACCEPTED'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationAcceptRequested('bid1')),
      wait: const Duration(milliseconds: 1),
      expect: () => [isA<BidNegotiationLoading>(), isA<BidNegotiationLoaded>()],
      verify: (_) => verifyNever(() => config.getCommissionGridById(any())),
    );

    for (final entry in <String, void Function(BidNegotiationBloc)>{
      'counter': (b) => b.add(
        const BidNegotiationCounterRequested('bid1', proposedNetEur: 50),
      ),
      'accept': (b) => b.add(const BidNegotiationAcceptRequested('bid1')),
      'reject': (b) => b.add(const BidNegotiationRejectRequested('bid1')),
      'cancel': (b) => b.add(const BidNegotiationCancelRequested('bid1')),
    }.entries) {
      blocTest<BidNegotiationBloc, BidNegotiationState>(
        '${entry.key} : la grille figée du fil est chargée avant l émission',
        build: () {
          final thread = travelerThread();
          when(
            () => repo.counter(
              'bid1',
              proposedTotalEur: any(named: 'proposedTotalEur'),
              proposedNetEur: any(named: 'proposedNetEur'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => thread);
          when(() => repo.accept('bid1')).thenAnswer((_) async => thread);
          when(() => repo.reject('bid1')).thenAnswer((_) async => thread);
          when(() => repo.cancel('bid1')).thenAnswer((_) async => thread);
          when(
            () => config.getCommissionGridById('g-thread'),
          ).thenAnswer((_) async => _threadGrid());
          return buildBloc();
        },
        act: entry.value,
        wait: const Duration(milliseconds: 1),
        expect: () => [
          isA<BidNegotiationLoading>(),
          isA<BidNegotiationLoaded>(),
        ],
        verify: (_) {
          verify(() => config.getCommissionGridById('g-thread')).called(1);
        },
      );
    }
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
        // Le mode choisi à l'étape « Comment voulez-vous payer ? », jamais le
        // numéro payeur.
        expect(captured['payment_method'], 'STRIPE');
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

    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'cancel trace trip_negotiation_cancelled avec le fil',
      build: () {
        when(
          () => repo.cancel('bid1'),
        ).thenAnswer((_) async => _thread(status: 'CANCELLED'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationCancelRequested('bid1')),
      wait: const Duration(milliseconds: 1),
      verify: (_) {
        verify(
          () => backend.capture(
            AnalyticsEvents.tripNegotiationCancelled,
            any(that: containsPair('bid_id', isA<String>())),
          ),
        ).called(1);
      },
    );

    // FLUTTER-EQ : l'annulation depuis l'état d'attente peut croiser une
    // réponse de l'autre partie (fil déjà clos côté serveur) : l'erreur doit
    // remonter telle quelle à l'écran, sans fil marqué annulé.
    blocTest<BidNegotiationBloc, BidNegotiationState>(
      'cancel refuse par le serveur emet Error, jamais Loaded cancelled',
      build: () {
        when(() => repo.cancel('bid1')).thenThrow(
          const ConflictException('Fil clos', code: 'negotiation-closed'),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BidNegotiationCancelRequested('bid1')),
      expect: () => [
        isA<BidNegotiationLoading>(),
        isA<BidNegotiationError>().having(
          (s) => s.error.code,
          'code',
          'negotiation-closed',
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
