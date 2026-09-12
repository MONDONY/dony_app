// Mocktail exige un jeu exact d'arguments nommés entre l'appel réel
// (`_repository.initiate(scope, phoneNumber: ..., provider: ...)`, toujours
// les deux, même nuls) et le `when()`/`verify()` correspondant : beaucoup de
// stubs ci-dessous répètent donc `phoneNumber: null`/`provider: null` là où
// c'est la valeur par défaut, uniquement pour que le mock matche l'appel.
// ignore_for_file: avoid_redundant_argument_values
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMobileMoneyRepository extends Mock implements MobileMoneyRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const MobileMoneyScope.bid('fallback'));
  });

  late MockMobileMoneyRepository repository;
  late MockAnalyticsService analytics;

  const bidId = '550e8400-e29b-41d4-a716-446655440000';
  const scope = MobileMoneyScope.bid(bidId);
  const threadId = '660e8400-e29b-41d4-a716-446655440111';
  const negotiationScope = MobileMoneyScope.negotiation(threadId);

  const liveDeposit = MobileMoneyDeposit(
    id: 'deposit-1',
    status: MobileMoneyDepositStatus.accepted,
    providerLabel: 'Wave',
    authorizationUrl: 'https://wave.test/pay?ref=abc',
  );
  const liveStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 50.0,
    deposit: liveDeposit,
  );
  const noDepositStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    amount: 50.0,
  );
  const escrowedStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'ACCEPTED',
    paymentStatus: 'ESCROW',
    amount: 50.0,
  );
  final deadline = DateTime(2026, 9, 8, 10);
  final statusNearDeadline = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    deadlineAt: deadline,
    amount: 50.0,
    deposit: liveDeposit,
  );

  // Catalogue payeur type : réseaux acceptés par le voyageur (Aminata),
  // opérateur détecté par pawaPay pré-coché.
  const catalog = MobileMoneyProviderCatalog(
    country: 'CI',
    currency: 'XOF',
    msisdnMasked: '+225 •••• 77',
    detected: 'ORANGE_CIV',
    providers: [
      MobileMoneyProviderOption(
        code: 'ORANGE_CIV',
        label: 'Orange Money',
        detected: true,
      ),
      MobileMoneyProviderOption(code: 'WAVE_CIV', label: 'Wave'),
    ],
    travelerAccepts: ['Orange Money', 'Wave'],
    travelerFirstName: 'Aminata',
  );

  setUp(() {
    repository = MockMobileMoneyRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  MobileMoneyPaymentBloc bloc({DateTime Function()? now}) =>
      MobileMoneyPaymentBloc(repository, analytics, now: now);

  test('état initial', () {
    expect(bloc().state, isA<MobileMoneyPaymentInitial>());
  });

  group('MobileMoneyPaymentOpened', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'dépôt déjà vivant : statut mappé directement, initiate jamais appelé',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>().having(
          (s) => s.status,
          'status',
          liveStatus,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => repository.initiate(
            any(),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        );
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en portée négociation : getStatus reçoit la portée '
      'négociation',
      build: () {
        when(
          () => repository.getStatus(negotiationScope),
        ).thenAnswer((_) async => escrowedStatus);
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentEscrowed>(),
      ],
      verify: (_) {
        verify(() => repository.getStatus(negotiationScope)).called(1);
        verifyNever(
          () => repository.initiate(
            any(),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        );
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en portée négociation, initiation : analytics '
      'mobileMoneyInitiated porte scope negotiation',
      build: () {
        when(
          () => repository.getStatus(negotiationScope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.initiate(
            negotiationScope,
            phoneNumber: null,
            provider: null,
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyInitiated,
            properties: {
              'provider': 'Wave',
              'chosen': false,
              'wave': true,
              'scope': 'negotiation',
            },
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en portée négociation sur une ligne CANCELLED résiduelle '
      '(fil revenu à payer, aucun dépôt vivant) : initiate appelé, '
      'AwaitingConfirmation',
      build: () {
        when(() => repository.getStatus(negotiationScope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: threadId,
            paymentStatus: 'CANCELLED',
            amount: 50.0,
          ),
        );
        when(
          () => repository.initiate(
            negotiationScope,
            phoneNumber: null,
            provider: null,
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>().having(
          (s) => s.status,
          'status',
          liveStatus,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.initiate(
            negotiationScope,
            phoneNumber: null,
            provider: null,
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en portée négociation après un dépôt refusé puis libéré '
      '(CANCELLED + dépôt FAILED) : initiate appelé, jamais Expired',
      build: () {
        when(() => repository.getStatus(negotiationScope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: threadId,
            paymentStatus: 'CANCELLED',
            amount: 50.0,
            deposit: MobileMoneyDeposit(
              id: 'd0',
              status: MobileMoneyDepositStatus.failed,
              failureCode: 'INSUFFICIENT_FUNDS',
            ),
          ),
        );
        when(
          () => repository.initiate(
            negotiationScope,
            phoneNumber: null,
            provider: null,
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        verify(
          () => repository.initiate(
            negotiationScope,
            phoneNumber: null,
            provider: null,
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture sur un bid annulé (bidStatus + paymentStatus CANCELLED) : '
      'Expired, initiate jamais appelé',
      build: () {
        when(() => repository.getStatus(scope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'CANCELLED',
            paymentStatus: 'CANCELLED',
            amount: 50.0,
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentExpired>(),
      ],
      verify: (_) {
        verifyNever(
          () => repository.initiate(
            any(),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        );
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en portée négociation, échéance passée sans libération '
      '(PENDING) : Expired, initiate jamais appelé',
      build: () {
        when(() => repository.getStatus(negotiationScope)).thenAnswer(
          (_) async => MobileMoneyPaymentStatus(
            subjectId: threadId,
            paymentStatus: 'PENDING',
            deadlineAt: deadline,
            amount: 50.0,
            deposit: liveDeposit,
          ),
        );
        return bloc(now: () => deadline.add(const Duration(minutes: 1)));
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentExpired>(),
      ],
      verify: (_) {
        verifyNever(
          () => repository.initiate(
            any(),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        );
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'déjà séquestré : Escrowed direct, initiate jamais appelé, analytics '
      'mobileMoneyConfirmed',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => escrowedStatus);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentEscrowed>(),
      ],
      verify: (_) {
        verifyNever(
          () => repository.initiate(
            any(),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        );
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyConfirmed,
            properties: {'scope': 'bid'},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'getStatus en échec → Error porte une AppException (jamais e.toString())',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenThrow(const OfflineException());
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>().having(
          (s) => s.error,
          'error',
          isA<OfflineException>(),
        ),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en portée négociation, initiate en échec après un statut '
      'sans dépôt → Error',
      build: () {
        when(
          () => repository.getStatus(negotiationScope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.initiate(
            negotiationScope,
            phoneNumber: null,
            provider: null,
          ),
        ).thenThrow(const ServerException());
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>().having(
          (s) => s.error,
          'error',
          isA<ServerException>(),
        ),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'l\'AppException levée par le repository conserve son code métier',
      build: () {
        when(() => repository.getStatus(scope)).thenThrow(
          const ValidationException(
            'Numéro invalide',
            code: 'invalid-phone-number',
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>().having(
          (s) => s.error,
          'error',
          isA<ValidationException>().having(
            (e) => e.code,
            'code',
            'invalid-phone-number',
          ),
        ),
      ],
    );
  });

  group('MobileMoneyPaymentOpened sans dépôt', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'charge le catalogue payeur et émet ChooseOperator, sans initier',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.providers(bidId, phoneNumber: null),
        ).thenAnswer((_) async => catalog);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          isLoadingCatalog: true,
        ),
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          catalog: catalog,
        ),
      ],
      verify: (_) => verifyNever(
        () => repository.initiate(
          any(),
          phoneNumber: any(named: 'phoneNumber'),
          provider: any(named: 'provider'),
        ),
      ),
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'catalogue en 404 (ancien back) : initiation directe sans opérateur',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.providers(bidId, phoneNumber: null),
        ).thenThrow(const NotFoundException());
        when(
          () => repository.initiate(scope, phoneNumber: null, provider: null),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          isLoadingCatalog: true,
        ),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'catalogue en erreur : ChooseOperator porte l\'erreur (bandeau)',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.providers(bidId, phoneNumber: null),
        ).thenThrow(const OfflineException());
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          isLoadingCatalog: true,
        ),
        isA<MobileMoneyPaymentChooseOperator>().having(
          (s) => s.error,
          'error',
          isA<OfflineException>(),
        ),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture avec un numéro payeur et sans dépôt vivant : le catalogue '
      'est demandé avec ce numéro',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.providers(bidId, phoneNumber: '+221771234567'),
        ).thenAnswer((_) async => catalog);
        return bloc();
      },
      act: (b) => b.add(
        const MobileMoneyPaymentOpened(
          scope: scope,
          phoneNumber: '+221771234567',
        ),
      ),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          payerPhone: '+221771234567',
          isLoadingCatalog: true,
        ),
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          catalog: catalog,
          payerPhone: '+221771234567',
        ),
      ],
      verify: (_) {
        verify(
          () => repository.providers(bidId, phoneNumber: '+221771234567'),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en portée négociation sans dépôt connu : initiate appelé '
      'directement, jamais de catalogue (pas de back pour la négociation)',
      build: () {
        when(
          () => repository.getStatus(negotiationScope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.initiate(
            negotiationScope,
            phoneNumber: null,
            provider: null,
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        verify(
          () => repository.initiate(
            negotiationScope,
            phoneNumber: null,
            provider: null,
          ),
        ).called(1);
        verifyNever(
          () => repository.providers(
            any(),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        );
      },
    );
  });

  group('MobileMoneyPaymentProvidersRequested', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'recharge le catalogue pour un autre numéro payeur, catalogue '
      'précédent gardé pendant le chargement',
      build: () {
        when(
          () => repository.providers(bidId, phoneNumber: '+22505'),
        ).thenAnswer((_) async => catalog);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChooseOperator(
        status: noDepositStatus,
        catalog: catalog,
      ),
      act: (b) => b.add(
        const MobileMoneyPaymentProvidersRequested(
          scope: scope,
          phoneNumber: '+22505',
        ),
      ),
      expect: () => [
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          catalog: catalog,
          payerPhone: '+22505',
          isLoadingCatalog: true,
        ),
        const MobileMoneyPaymentChooseOperator(
          status: noDepositStatus,
          catalog: catalog,
          payerPhone: '+22505',
        ),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'depuis DepositFailed (« Réessayer ») : revient au choix de '
      'l\'opérateur',
      build: () {
        when(
          () => repository.providers(bidId, phoneNumber: null),
        ).thenAnswer((_) async => catalog);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentDepositFailed(liveStatus),
      act: (b) =>
          b.add(const MobileMoneyPaymentProvidersRequested(scope: scope)),
      expect: () => [
        const MobileMoneyPaymentChooseOperator(
          status: liveStatus,
          isLoadingCatalog: true,
        ),
        const MobileMoneyPaymentChooseOperator(
          status: liveStatus,
          catalog: catalog,
        ),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sans statut connu (état Initial) : rien à recharger, aucune émission',
      build: () => bloc(),
      act: (b) =>
          b.add(const MobileMoneyPaymentProvidersRequested(scope: scope)),
      expect: () => [],
      verify: (_) {
        verifyNever(
          () => repository.providers(
            any(),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        );
      },
    );
  });

  group('MobileMoneyPaymentInitiateRequested', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'numéro transmis au repository, résultat mappé, analytics '
      'mobileMoneyInitiated',
      build: () {
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+221771234567',
            provider: null,
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) => b.add(
        const MobileMoneyPaymentInitiateRequested(
          scope: scope,
          phoneNumber: '+221771234567',
        ),
      ),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        verify(
          () => repository.initiate(
            scope,
            phoneNumber: '+221771234567',
            provider: null,
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sans numéro : repository appelé sans phoneNumber',
      build: () {
        when(
          () => repository.initiate(scope, phoneNumber: null, provider: null),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentInitiateRequested(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        verify(
          () => repository.initiate(scope, phoneNumber: null, provider: null),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'échec → Error',
      build: () {
        when(
          () => repository.initiate(scope, phoneNumber: null, provider: null),
        ).thenThrow(const NetworkException('boom'));
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentInitiateRequested(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>(),
      ],
    );
  });

  group('MobileMoneyPaymentInitiateRequested avec opérateur', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'transmet numéro et opérateur, émet Loading puis AwaitingConfirmation',
      build: () {
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+22505',
            provider: 'WAVE_CIV',
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) => b.add(
        const MobileMoneyPaymentInitiateRequested(
          scope: scope,
          phoneNumber: '+22505',
          provider: 'WAVE_CIV',
        ),
      ),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyInitiated,
            properties: {
              'provider': 'Wave',
              'chosen': true,
              'wave': true,
              'scope': 'bid',
            },
          ),
        ).called(1);
      },
    );
  });

  group('MobileMoneyStatusPolled', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'silencieux : jamais de Loading, transition directe',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => escrowedStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [isA<MobileMoneyPaymentEscrowed>()],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'erreur réseau ignorée depuis AwaitingConfirmation : aucune émission',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenThrow(const OfflineException());
        return bloc();
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'erreur réseau depuis Initial → Error (première tentative)',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenThrow(const OfflineException());
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [isA<MobileMoneyPaymentError>()],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'erreur réseau depuis Loading → Error',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenThrow(const OfflineException());
        return bloc();
      },
      seed: () => const MobileMoneyPaymentLoading(),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [isA<MobileMoneyPaymentError>()],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'aucun dépôt renvoyé pendant un sondage : état inchangé',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'isExpired avec now avant la deadline : reste AwaitingConfirmation',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => statusNearDeadline);
        return bloc(now: () => deadline.subtract(const Duration(minutes: 1)));
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [isA<MobileMoneyPaymentAwaitingConfirmation>()],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'isExpired avec now après la deadline : passe à Expired',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => statusNearDeadline);
        return bloc(now: () => deadline.add(const Duration(minutes: 1)));
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [isA<MobileMoneyPaymentExpired>()],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sondage en portée négociation : le dépôt suivi vient d\'être libéré '
      '(CANCELLED) → Expired, jamais de nouvelle initiation',
      build: () {
        when(() => repository.getStatus(negotiationScope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: threadId,
            paymentStatus: 'CANCELLED',
            amount: 50.0,
          ),
        );
        return bloc();
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: negotiationScope)),
      expect: () => [isA<MobileMoneyPaymentExpired>()],
      verify: (_) {
        verifyNever(
          () => repository.initiate(
            any(),
            phoneNumber: any(named: 'phoneNumber'),
          ),
        );
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'plusieurs sondages Escrowed de suite : mobileMoneyConfirmed une seule '
      'fois',
      build: () {
        var call = 0;
        when(() => repository.getStatus(scope)).thenAnswer((_) async {
          call++;
          return call == 1
              ? const MobileMoneyPaymentStatus(
                  subjectId: bidId,
                  subjectStatus: 'ACCEPTED',
                  paymentStatus: 'ESCROW',
                  amount: 50.0,
                )
              : const MobileMoneyPaymentStatus(
                  subjectId: bidId,
                  subjectStatus: 'ACCEPTED',
                  paymentStatus: 'RELEASED',
                  amount: 50.0,
                );
        });
        return bloc();
      },
      act: (b) async {
        b.add(const MobileMoneyStatusPolled(scope: scope));
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyStatusPolled(scope: scope));
      },
      expect: () => [
        isA<MobileMoneyPaymentEscrowed>(),
        isA<MobileMoneyPaymentEscrowed>(),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyConfirmed,
            properties: {'scope': 'bid'},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'plusieurs sondages DepositFailed de suite : mobileMoneyFailed une '
      'seule fois',
      build: () {
        var call = 0;
        when(() => repository.getStatus(scope)).thenAnswer((_) async {
          call++;
          return call == 1
              ? const MobileMoneyPaymentStatus(
                  subjectId: bidId,
                  subjectStatus: 'AWAITING_PAYMENT',
                  amount: 50.0,
                  deposit: MobileMoneyDeposit(
                    id: 'd1',
                    status: MobileMoneyDepositStatus.failed,
                    failureCode: 'INSUFFICIENT_FUNDS',
                  ),
                )
              : const MobileMoneyPaymentStatus(
                  subjectId: bidId,
                  subjectStatus: 'AWAITING_PAYMENT',
                  amount: 50.0,
                  deposit: MobileMoneyDeposit(
                    id: 'd2',
                    status: MobileMoneyDepositStatus.submitRejected,
                    failureCode: 'INVALID_PIN',
                  ),
                );
        });
        return bloc();
      },
      act: (b) async {
        b.add(const MobileMoneyStatusPolled(scope: scope));
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyStatusPolled(scope: scope));
      },
      expect: () => [
        isA<MobileMoneyPaymentDepositFailed>(),
        isA<MobileMoneyPaymentDepositFailed>(),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyFailed,
            properties: {'failure_code': 'INSUFFICIENT_FUNDS', 'scope': 'bid'},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'DepositFailed sans failureCode : properties failure_code vide',
      build: () {
        when(() => repository.getStatus(scope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'AWAITING_PAYMENT',
            amount: 50.0,
            deposit: MobileMoneyDeposit(
              id: 'd1',
              status: MobileMoneyDepositStatus.failed,
            ),
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [isA<MobileMoneyPaymentDepositFailed>()],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyFailed,
            properties: {'failure_code': '', 'scope': 'bid'},
          ),
        ).called(1);
      },
    );
  });
}
