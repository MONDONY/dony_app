// Mocktail exige un jeu exact d'arguments nommés entre l'appel réel
// (`_repository.initiate(scope, phoneNumber: ..., provider: ...)`, toujours
// les deux, même nuls) et le `when()`/`verify()` correspondant : beaucoup de
// stubs ci-dessous répètent donc `phoneNumber: null`/`provider: null` là où
// c'est la valeur par défaut, uniquement pour que le mock matche l'appel.
// ignore_for_file: avoid_redundant_argument_values
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_accepted_operators.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
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

  // Opérateurs acceptés par le voyageur (Aminata) pour ce colis.
  const accepted = MobileMoneyAcceptedOperators(
    currency: 'XOF',
    travelerFirstName: 'Aminata',
    providers: {'ORANGE_CIV', 'WAVE_CIV'},
  );
  const failedDeposit = MobileMoneyDeposit(
    id: 'deposit-f',
    status: MobileMoneyDepositStatus.failed,
    provider: 'ORANGE_CIV',
    providerLabel: 'Orange Money',
    failureCode: 'INSUFFICIENT_FUNDS',
    failureReasonCode: 'insufficient-balance',
  );
  const failedStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 50.0,
    deposit: failedDeposit,
  );
  // Échéance passée avec un dépôt refusé : rien ne peut plus aboutir.
  final failedNearDeadline = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    deadlineAt: deadline,
    amount: 50.0,
    deposit: failedDeposit,
  );

  void verifyNoInitiate() => verifyNever(
    () => repository.initiate(
      any(),
      phoneNumber: any(named: 'phoneNumber'),
      provider: any(named: 'provider'),
    ),
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
            provider: any(named: 'provider'),
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
            provider: any(named: 'provider'),
          ),
        );
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'portée négociation, initiation depuis le choix du payeur : analytics '
      'mobileMoneyInitiated porte scope negotiation',
      build: () {
        when(
          () => repository.initiate(
            negotiationScope,
            phoneNumber: null,
            provider: null,
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      act: (b) => b.add(
        const MobileMoneyPaymentInitiateRequested(scope: negotiationScope),
      ),
      expect: () => [
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          isSubmitting: true,
        ),
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
      '(fil revenu à payer, aucun dépôt vivant) : choix du payeur, jamais '
      'Expired ni initiation',
      build: () {
        when(() => repository.getStatus(negotiationScope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: threadId,
            paymentStatus: 'CANCELLED',
            amount: 50.0,
          ),
        );
        when(
          () => repository.acceptedOperators(negotiationScope),
        ).thenAnswer((_) async => accepted);
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentChoosePayer>().having(
          (s) => s.accepted,
          'accepted',
          accepted,
        ),
      ],
      verify: (_) => verifyNoInitiate(),
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en portée négociation après un dépôt refusé puis libéré '
      '(CANCELLED + dépôt FAILED) : choix du payeur, jamais Expired',
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
          () => repository.acceptedOperators(negotiationScope),
        ).thenAnswer((_) async => accepted);
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentChoosePayer>(),
      ],
      verify: (_) => verifyNoInitiate(),
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
            provider: any(named: 'provider'),
          ),
        );
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en portée négociation, échéance passée avec un dépôt encore '
      'ouvert (PENDING) : Overdue, jamais Expired, initiate jamais appelé',
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
        isA<MobileMoneyPaymentOverdue>(),
      ],
      verify: (_) => verifyNoInitiate(),
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
            provider: any(named: 'provider'),
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
      'opened_acceptedOperatorsServerError_emitsChoosePayerUnrestricted : '
      'une autre erreur que 404 ne bloque pas le paiement, le back revérifie '
      'à l\'initiation',
      build: () {
        when(
          () => repository.getStatus(negotiationScope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.acceptedOperators(negotiationScope),
        ).thenThrow(const ServerException());
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      ],
      verify: (_) => verifyNoInitiate(),
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
      'opened_noDeposit_bid_emitsChoosePayerWithAccepted',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.acceptedOperators(scope),
        ).thenAnswer((_) async => accepted);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: accepted,
        ),
      ],
      verify: (b) {
        verify(() => repository.acceptedOperators(scope)).called(1);
        verifyNoInitiate();
        expect(b.canResend, isFalse);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'opened_noDeposit_negotiation_emitsChoosePayerWithAccepted',
      build: () {
        when(
          () => repository.getStatus(negotiationScope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.acceptedOperators(negotiationScope),
        ).thenAnswer((_) async => accepted);
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: accepted,
        ),
      ],
      verify: (_) {
        verify(() => repository.acceptedOperators(negotiationScope)).called(1);
        verifyNoInitiate();
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'opened_acceptedOperators404_emitsChoosePayerUnrestricted : back '
      'ancien, aucune restriction (accepted nul), paiement possible',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        // Le repository traduit le 404 d'un ancien back en `null`.
        when(
          () => repository.acceptedOperators(scope),
        ).thenAnswer((_) async => null);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      ],
      verify: (_) => verifyNoInitiate(),
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'bid avec ligne CANCELLED résiduelle : choix du payeur, jamais Expired',
      build: () {
        when(() => repository.getStatus(scope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'AWAITING_PAYMENT',
            paymentStatus: 'CANCELLED',
            amount: 50.0,
          ),
        );
        when(
          () => repository.acceptedOperators(scope),
        ).thenAnswer((_) async => accepted);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentChoosePayer>(),
      ],
      verify: (_) => verifyNoInitiate(),
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'opened_liveDeposit_emitsAwaiting_noSecondInitiate : écran rouvert '
      'depuis la notification, attente reprise, aucun choix ni second dépôt',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      ],
      verify: (b) {
        verifyNoInitiate();
        verifyNever(() => repository.acceptedOperators(any()));
        // Numéro complet inconnu : « Renvoyer une demande » impossible.
        expect(b.canResend, isFalse);
      },
    );
  });

  group('initiation depuis le choix du payeur', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'choix validé : isSubmitting puis AwaitingConfirmation, numéro et '
      'opérateur transmis',
      build: () {
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(
        status: noDepositStatus,
        accepted: accepted,
      ),
      act: (b) => b.add(
        const MobileMoneyPaymentInitiateRequested(
          scope: scope,
          phoneNumber: '+2250707070707',
          provider: 'ORANGE_CIV',
        ),
      ),
      expect: () => [
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: accepted,
          isSubmitting: true,
        ),
        const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      ],
      verify: (b) => expect(b.canResend, isTrue),
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'initiate_422_backToChoosePayerWithError : bandeau dans le choix, '
      'accepted conservé, mobile_money_failed stage initiate',
      build: () {
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'MTN_MOMO_CIV',
          ),
        ).thenThrow(
          const ValidationException(
            'Opérateur refusé',
            code: 'mobile-money-operator-not-accepted',
          ),
        );
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(
        status: noDepositStatus,
        accepted: accepted,
      ),
      act: (b) => b.add(
        const MobileMoneyPaymentInitiateRequested(
          scope: scope,
          phoneNumber: '+2250707070707',
          provider: 'MTN_MOMO_CIV',
        ),
      ),
      expect: () => [
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: accepted,
          isSubmitting: true,
        ),
        isA<MobileMoneyPaymentChoosePayer>()
            .having((s) => s.accepted, 'accepted', accepted)
            .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
            .having(
              (s) => s.error,
              'error',
              isA<ValidationException>().having(
                (e) => e.code,
                'code',
                'mobile-money-operator-not-accepted',
              ),
            ),
      ],
      verify: (b) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyFailed,
            properties: {
              'failure_code': 'mobile-money-operator-not-accepted',
              'stage': 'initiate',
              'scope': 'bid',
            },
          ),
        ).called(1);
        // Aucun dépôt créé : rien à renvoyer.
        expect(b.canResend, isFalse);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'nouvel essai après une erreur : le bandeau disparaît pendant l\'envoi',
      build: () {
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(
        status: noDepositStatus,
        error: OfflineException(),
      ),
      act: (b) => b.add(
        const MobileMoneyPaymentInitiateRequested(
          scope: scope,
          phoneNumber: '+2250707070707',
          provider: 'ORANGE_CIV',
        ),
      ),
      expect: () => [
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          isSubmitting: true,
        ),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
    );
  });

  group('garde anti second dépôt (InitiateRequested)', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'double appui dans la même frame : un seul initiate',
      build: () {
        final pending = Completer<MobileMoneyPaymentStatus>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete(liveStatus);
        });
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer((_) => pending.future);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      act: (b) {
        const e = MobileMoneyPaymentInitiateRequested(
          scope: scope,
          phoneNumber: '+2250707070707',
          provider: 'ORANGE_CIV',
        );
        b
          ..add(e)
          ..add(e);
      },
      expect: () => [
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          isSubmitting: true,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).called(1);
      },
    );

    for (final entry in <String, MobileMoneyPaymentState Function()>{
      'AwaitingConfirmation': () =>
          const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      'Overdue': () => MobileMoneyPaymentOverdue(statusNearDeadline),
      'Escrowed': () => const MobileMoneyPaymentEscrowed(escrowedStatus),
      'Loading': () => const MobileMoneyPaymentLoading(),
    }.entries) {
      blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        'InitiateRequested en ${entry.key} : aucun initiate, aucune émission',
        build: () => bloc(),
        seed: entry.value,
        act: (b) => b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ),
        expect: () => [],
        verify: (_) => verifyNoInitiate(),
      );
    }
  });

  group('MobileMoneyPaymentResendRequested', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'resend_afterFailed_reusesPhoneAndProvider',
      build: () {
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer((_) async => liveStatus);
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => failedStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(
        status: noDepositStatus,
        accepted: accepted,
      ),
      act: (b) async {
        b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyStatusPolled(scope: scope));
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyPaymentResendRequested(scope: scope));
      },
      expect: () => [
        isA<MobileMoneyPaymentChoosePayer>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
        const MobileMoneyPaymentDepositFailed(failedStatus),
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      ],
      verify: (b) {
        verify(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).called(2);
        expect(b.canResend, isTrue);
        // Chaque tentative reste tracée, sans numéro.
        final props = verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyInitiated,
            properties: captureAny(named: 'properties'),
          ),
        ).captured;
        expect(props, hasLength(2));
        for (final p in props.cast<Map<String, Object?>>()) {
          expect(p.values, isNot(contains('+2250707070707')));
        }
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'resend_unknownPayer_noop : écran rouvert sur un dépôt refusé, numéro '
      'complet inconnu, aucune émission ni initiation',
      build: () => bloc(),
      seed: () => const MobileMoneyPaymentDepositFailed(failedStatus),
      act: (b) => b.add(const MobileMoneyPaymentResendRequested(scope: scope)),
      expect: () => [],
      verify: (b) {
        verifyNoInitiate();
        expect(b.canResend, isFalse);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'relance en échec : Error, mobile_money_failed stage initiate',
      build: () {
        var call = 0;
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer((_) async {
          call++;
          if (call == 2) throw const OfflineException();
          return failedStatus;
        });
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      act: (b) async {
        b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyPaymentResendRequested(scope: scope));
      },
      expect: () => [
        isA<MobileMoneyPaymentChoosePayer>(),
        const MobileMoneyPaymentDepositFailed(failedStatus),
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>().having(
          (s) => s.error,
          'error',
          isA<OfflineException>(),
        ),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyFailed,
            properties: any(
              named: 'properties',
              that: containsPair('stage', 'initiate'),
            ),
          ),
        ).called(1);
      },
    );
  });

  group('MobileMoneyPaymentResendRequested hors dépôt refusé', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'couple connu mais dépôt en cours : aucun second dépôt',
      build: () {
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      act: (b) async {
        b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyPaymentResendRequested(scope: scope));
      },
      expect: () => [
        isA<MobileMoneyPaymentChoosePayer>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (b) {
        verify(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).called(1);
        expect(b.canResend, isTrue);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'dépôt créé sans numéro explicite : aucun numéro complet à réutiliser',
      build: () {
        when(
          () => repository.initiate(scope, phoneNumber: null, provider: null),
        ).thenAnswer((_) async => failedStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      act: (b) async {
        b.add(const MobileMoneyPaymentInitiateRequested(scope: scope));
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyPaymentResendRequested(scope: scope));
      },
      expect: () => [
        isA<MobileMoneyPaymentChoosePayer>(),
        const MobileMoneyPaymentDepositFailed(failedStatus),
      ],
      verify: (b) {
        verify(
          () => repository.initiate(scope, phoneNumber: null, provider: null),
        ).called(1);
        expect(b.canResend, isFalse);
      },
    );
  });

  group('MobileMoneyPaymentChangePayerRequested', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'changePayer_afterFailed_emitsChoosePayer_withoutRefetch',
      build: () {
        var statusCalls = 0;
        when(() => repository.getStatus(scope)).thenAnswer((_) async {
          statusCalls++;
          return statusCalls == 1 ? noDepositStatus : failedStatus;
        });
        when(
          () => repository.acceptedOperators(scope),
        ).thenAnswer((_) async => accepted);
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer((_) async => liveStatus);
        return bloc();
      },
      act: (b) async {
        b.add(const MobileMoneyPaymentOpened(scope: scope));
        await Future<void>.delayed(Duration.zero);
        b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyStatusPolled(scope: scope));
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyPaymentChangePayerRequested(scope: scope));
      },
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: accepted,
        ),
        isA<MobileMoneyPaymentChoosePayer>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
        const MobileMoneyPaymentDepositFailed(failedStatus),
        const MobileMoneyPaymentChoosePayer(
          status: failedStatus,
          accepted: accepted,
        ),
      ],
      verify: (_) {
        verify(() => repository.acceptedOperators(scope)).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'opérateurs acceptés jamais chargés (écran rouvert sur un dépôt '
      'refusé) : chargés une fois au changement de payeur',
      build: () {
        when(
          () => repository.acceptedOperators(scope),
        ).thenAnswer((_) async => accepted);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentDepositFailed(failedStatus),
      act: (b) async {
        b.add(const MobileMoneyPaymentChangePayerRequested(scope: scope));
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyPaymentChangePayerRequested(scope: scope));
      },
      expect: () => [
        const MobileMoneyPaymentChoosePayer(
          status: failedStatus,
          accepted: accepted,
        ),
      ],
      verify: (_) {
        verify(() => repository.acceptedOperators(scope)).called(1);
      },
    );

    late Completer<MobileMoneyAcceptedOperators?> slowAccepted;
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'relance pendant la lecture des opérateurs du changement de payeur : '
      'l\'attente du nouveau dépôt reste affichée',
      build: () {
        slowAccepted = Completer<MobileMoneyAcceptedOperators?>();
        when(
          () => repository.acceptedOperators(scope),
        ).thenAnswer((_) => slowAccepted.future);
        var call = 0;
        when(
          () => repository.initiate(
            scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer((_) async => ++call == 1 ? failedStatus : liveStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      act: (b) async {
        // Premier dépôt refusé : couple connu, état DepositFailed.
        b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        // Changement de payeur (lecture des opérateurs en attente), puis
        // relance qui lance un dépôt vivant avant la fin de la lecture.
        b
          ..add(const MobileMoneyPaymentChangePayerRequested(scope: scope))
          ..add(const MobileMoneyPaymentResendRequested(scope: scope));
        await Future<void>.delayed(Duration.zero);
        // La lecture se termine après coup : rien ne doit recouvrir l'attente.
        slowAccepted.complete(accepted);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<MobileMoneyPaymentChoosePayer>(),
        const MobileMoneyPaymentDepositFailed(failedStatus),
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      ],
      verify: (b) {
        expect(b.state, isA<MobileMoneyPaymentAwaitingConfirmation>());
        verify(() => repository.acceptedOperators(scope)).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'chargement des opérateurs en échec au changement de payeur : choix '
      'sans restriction',
      build: () {
        when(
          () => repository.acceptedOperators(scope),
        ).thenThrow(const OfflineException());
        return bloc();
      },
      seed: () => const MobileMoneyPaymentDepositFailed(failedStatus),
      act: (b) =>
          b.add(const MobileMoneyPaymentChangePayerRequested(scope: scope)),
      expect: () => [const MobileMoneyPaymentChoosePayer(status: failedStatus)],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sans dépôt refusé (dépôt en cours, séquestre, chargement) : aucune '
      'émission, un second dépôt ne peut pas partir',
      build: () => bloc(),
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
      act: (b) =>
          b.add(const MobileMoneyPaymentChangePayerRequested(scope: scope)),
      expect: () => [],
      verify: (_) {
        verifyNever(() => repository.acceptedOperators(any()));
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
      'sondage pendant le choix du payeur sans nouveau dépôt : état '
      'inchangé, aucune initiation',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(
        status: noDepositStatus,
        accepted: accepted,
      ),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [],
      verify: (_) => verifyNoInitiate(),
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sondage tardif pendant le choix d\'un autre payeur : l\'ancien dépôt '
      'refusé ne fait pas quitter le choix',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => failedStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(
        status: failedStatus,
        accepted: accepted,
      ),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sondage pendant le choix du payeur d\'un fil revenu à payer : la ligne '
      'CANCELLED résiduelle ne devient pas une expiration',
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
      seed: () => const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: negotiationScope)),
      expect: () => [],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sondage pendant le choix du payeur : un séquestre arrivé entre-temps '
      'ferme le choix en succès',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => escrowedStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentChoosePayer(status: failedStatus),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [const MobileMoneyPaymentEscrowed(escrowedStatus)],
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
      'poll_pastDeadline_depositLive_emitsOverdue_keepsPolling : '
      'l\'expéditeur valide à la dernière seconde, jamais « délai dépassé »',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => statusNearDeadline);
        return bloc(now: () => deadline.add(const Duration(minutes: 1)));
      },
      seed: () => MobileMoneyPaymentAwaitingConfirmation(statusNearDeadline),
      act: (b) async {
        b.add(const MobileMoneyStatusPolled(scope: scope));
        await Future<void>.delayed(Duration.zero);
        // Le sondage continue : un second passage reste en Overdue.
        b.add(const MobileMoneyStatusPolled(scope: scope));
      },
      expect: () => [MobileMoneyPaymentOverdue(statusNearDeadline)],
      verify: (_) {
        verify(() => repository.getStatus(scope)).called(2);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyExpired,
            properties: any(named: 'properties'),
          ),
        );
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.paymentFailed,
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'poll_escrowWhileOverdue_emitsEscrowed : le séquestre qui arrive après '
      'l\'échéance ferme l\'écran en succès',
      build: () {
        when(() => repository.getStatus(scope)).thenAnswer(
          (_) async => MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'ACCEPTED',
            paymentStatus: 'ESCROW',
            deadlineAt: deadline,
            amount: 50.0,
          ),
        );
        return bloc(now: () => deadline.add(const Duration(minutes: 3)));
      },
      seed: () => MobileMoneyPaymentOverdue(statusNearDeadline),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [isA<MobileMoneyPaymentEscrowed>()],
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
      'poll_pastDeadline_depositFailed_emitsExpired',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => failedNearDeadline);
        return bloc(now: () => deadline.add(const Duration(minutes: 1)));
      },
      seed: () => MobileMoneyPaymentOverdue(statusNearDeadline),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [MobileMoneyPaymentExpired(failedNearDeadline)],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'échéance passée sans aucun dépôt : Expired',
      build: () {
        when(() => repository.getStatus(scope)).thenAnswer(
          (_) async => MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'AWAITING_PAYMENT',
            deadlineAt: deadline,
            amount: 50.0,
          ),
        );
        return bloc(now: () => deadline.add(const Duration(minutes: 1)));
      },
      seed: () => const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [isA<MobileMoneyPaymentExpired>()],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sujet annulé avec un dépôt encore ouvert : Expired, jamais Overdue',
      build: () {
        when(() => repository.getStatus(scope)).thenAnswer(
          (_) async => MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'CANCELLED',
            paymentStatus: 'PENDING',
            deadlineAt: deadline,
            amount: 50.0,
            deposit: liveDeposit,
          ),
        );
        return bloc(now: () => deadline.add(const Duration(minutes: 1)));
      },
      seed: () => MobileMoneyPaymentAwaitingConfirmation(statusNearDeadline),
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
            provider: any(named: 'provider'),
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

  group('Equatable des events (T9-cov)', () {
    test('MobileMoneyPaymentResendRequested et ChangePayerRequested : '
        'égaux par portée, distincts entre eux', () {
      const resend = MobileMoneyPaymentResendRequested(scope: scope);
      const change = MobileMoneyPaymentChangePayerRequested(scope: scope);
      expect(
        resend,
        equals(const MobileMoneyPaymentResendRequested(scope: scope)),
      );
      expect(
        resend,
        isNot(
          equals(
            const MobileMoneyPaymentResendRequested(scope: negotiationScope),
          ),
        ),
      );
      expect(
        change,
        isNot(
          equals(
            const MobileMoneyPaymentChangePayerRequested(
              scope: negotiationScope,
            ),
          ),
        ),
      );
      expect(resend, isNot(equals(change)));
    });

    test('MobileMoneyPaymentInitiateRequested avec provider : deux instances '
        'égales, différentes par scope, phoneNumber et provider', () {
      const a = MobileMoneyPaymentInitiateRequested(
        scope: scope,
        phoneNumber: '+221771234567',
        provider: 'ORANGE_CIV',
      );
      const b = MobileMoneyPaymentInitiateRequested(
        scope: scope,
        phoneNumber: '+221771234567',
        provider: 'ORANGE_CIV',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(
        a,
        isNot(
          equals(
            const MobileMoneyPaymentInitiateRequested(
              scope: negotiationScope,
              phoneNumber: '+221771234567',
              provider: 'ORANGE_CIV',
            ),
          ),
        ),
      );
      expect(
        a,
        isNot(
          equals(
            const MobileMoneyPaymentInitiateRequested(
              scope: scope,
              provider: 'ORANGE_CIV',
            ),
          ),
        ),
      );
      // provider : champ ajouté par le couplage à l'étape « Avec quel
      // opérateur ? », il doit peser dans l'égalité.
      expect(
        a,
        isNot(
          equals(
            const MobileMoneyPaymentInitiateRequested(
              scope: scope,
              phoneNumber: '+221771234567',
              provider: 'WAVE_CIV',
            ),
          ),
        ),
      );
    });
  });

  // Expirations et échecs d'appel : ils n'atteignaient jamais PostHog, seuls
  // les dépôts refusés par l'opérateur y figuraient.
  group('analytics expiration et erreurs', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'passage à Expired : mobile_money_expired une seule fois',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => failedNearDeadline);
        return bloc(now: () => deadline.add(const Duration(minutes: 1)));
      },
      act: (b) => b
        ..add(const MobileMoneyStatusPolled(scope: scope))
        ..add(const MobileMoneyStatusPolled(scope: scope)),
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyExpired,
            properties: {'scope': 'bid'},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'initiation refusée : mobile_money_failed stage initiate avec le code',
      build: () {
        when(
          () => repository.initiate(
            scope,
            phoneNumber: null,
            provider: 'WAVE_CIV',
          ),
        ).thenThrow(
          const ValidationException(
            'Numéro invalide',
            code: 'mobile-money/invalid-msisdn',
          ),
        );
        return bloc();
      },
      act: (b) => b.add(
        const MobileMoneyPaymentInitiateRequested(
          scope: scope,
          provider: 'WAVE_CIV',
        ),
      ),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>(),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyFailed,
            properties: {
              'failure_code': 'mobile-money/invalid-msisdn',
              'stage': 'initiate',
              'scope': 'bid',
            },
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture en échec : stage open, code unknown sans code métier',
      build: () {
        when(
          () => repository.getStatus(negotiationScope),
        ).thenThrow(Exception('réseau'));
        return bloc();
      },
      act: (b) =>
          b.add(const MobileMoneyPaymentOpened(scope: negotiationScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>(),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyFailed,
            properties: {
              'failure_code': 'unknown',
              'stage': 'open',
              'scope': 'negotiation',
            },
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sondage en échec avant tout affichage : stage poll',
      build: () {
        when(() => repository.getStatus(scope)).thenThrow(Exception('réseau'));
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      expect: () => [isA<MobileMoneyPaymentError>()],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyFailed,
            properties: any(
              named: 'properties',
              that: containsPair('stage', 'poll'),
            ),
          ),
        ).called(1);
      },
    );
  });

  group('portée supplément de prix (PR A3)', () {
    const supplementId = '770e8400-e29b-41d4-a716-446655440222';
    const supplementScope = MobileMoneyScope.supplement(
      bidId: bidId,
      supplementId: supplementId,
    );
    // Statut du supplément : `bidStatus` est celui du colis (déjà payé).
    const pending = MobileMoneyPaymentStatus(
      subjectId: bidId,
      subjectStatus: 'ACCEPTED',
      paymentStatus: 'PENDING',
      amount: 1500,
    );
    const failedDeposit = MobileMoneyDeposit(
      id: 'deposit-s',
      status: MobileMoneyDepositStatus.failed,
      providerLabel: 'Orange Money',
      failureCode: 'PAYER_NOT_FOUND',
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'opened_noDeposit_supplement_emitsChoosePayerWithAccepted : opérateurs '
      'acceptés lus sur la portée du supplément',
      build: () {
        when(
          () => repository.getStatus(supplementScope),
        ).thenAnswer((_) async => pending);
        when(
          () => repository.acceptedOperators(supplementScope),
        ).thenAnswer((_) async => accepted);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: supplementScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChoosePayer(
          status: pending,
          accepted: accepted,
        ),
      ],
      verify: (_) {
        verify(() => repository.acceptedOperators(supplementScope)).called(1);
        verifyNoInitiate();
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'supplément clos (CANCELLED) : expiration affichée, ni choix du payeur '
      'ni dépôt relancé',
      build: () {
        when(() => repository.getStatus(supplementScope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'ACCEPTED',
            paymentStatus: 'CANCELLED',
            amount: 1500,
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: supplementScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentExpired>(),
      ],
      verify: (_) {
        verifyNoInitiate();
        verifyNever(() => repository.acceptedOperators(any()));
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'supplément remboursé : fenêtre close',
      build: () {
        when(() => repository.getStatus(supplementScope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            paymentStatus: 'REFUNDED',
            amount: 1500,
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: supplementScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentExpired>(),
      ],
    );

    for (final refunding in ['REFUND_PENDING', 'REFUNDING']) {
      blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        'remboursement en cours ($refunding) : état terminal, jamais '
        'd\'attente sans fin ni payment_failed',
        build: () {
          when(() => repository.getStatus(supplementScope)).thenAnswer(
            (_) async => MobileMoneyPaymentStatus(
              subjectId: bidId,
              paymentStatus: refunding,
              deadlineAt: DateTime.now().add(const Duration(hours: 1)),
              amount: 1500,
            ),
          );
          return bloc();
        },
        seed: () => const MobileMoneyPaymentAwaitingConfirmation(pending),
        act: (b) =>
            b.add(const MobileMoneyStatusPolled(scope: supplementScope)),
        expect: () => [isA<MobileMoneyPaymentExpired>()],
        verify: (_) {
          verifyNever(
            () => analytics.logEvent(
              AnalyticsEvents.paymentFailed,
              properties: any(named: 'properties'),
            ),
          );
          verifyNever(
            () => analytics.logEvent(
              AnalyticsEvents.mobileMoneyExpired,
              properties: any(named: 'properties'),
            ),
          );
        },
      );
    }

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'statut inconnu du back, échéance passée : expiration (le sondage '
      's\'arrête), pas d\'attente sans fin',
      build: () {
        when(() => repository.getStatus(supplementScope)).thenAnswer(
          (_) async => MobileMoneyPaymentStatus(
            subjectId: bidId,
            paymentStatus: 'SOMETHING_NEW',
            deadlineAt: DateTime(2020),
            amount: 1500,
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: supplementScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentExpired>(),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'statut inconnu du back, échéance à venir : affichage « en cours », '
      'sans planter ni rouvrir le choix du payeur',
      build: () {
        when(() => repository.getStatus(supplementScope)).thenAnswer(
          (_) async => MobileMoneyPaymentStatus(
            subjectId: bidId,
            paymentStatus: 'SOMETHING_NEW',
            deadlineAt: DateTime.now().add(const Duration(hours: 1)),
            amount: 1500,
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: supplementScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        verifyNoInitiate();
        verifyNever(() => repository.acceptedOperators(any()));
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'échéance de 2 h passée avec un dépôt encore ouvert : Overdue, pas '
      'Expired (le supplément attend le statut final)',
      build: () {
        when(() => repository.getStatus(supplementScope)).thenAnswer(
          (_) async => MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'ACCEPTED',
            paymentStatus: 'PENDING',
            deadlineAt: deadline,
            amount: 1500,
            deposit: liveDeposit,
          ),
        );
        return bloc(now: () => deadline.add(const Duration(minutes: 1)));
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(pending),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: supplementScope)),
      expect: () => [isA<MobileMoneyPaymentOverdue>()],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'séquestre : payment_succeeded émis une fois, method mobile_money, '
      'context bid_supplement, sans PII',
      build: () {
        when(
          () => repository.getStatus(supplementScope),
        ).thenAnswer((_) async => escrowedStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(pending),
      act: (b) async {
        b.add(const MobileMoneyStatusPolled(scope: supplementScope));
        await Future<void>.delayed(Duration.zero);
        // Un second sondage qui confirme le même séquestre ne réémet rien.
        b.add(const MobileMoneyStatusPolled(scope: supplementScope));
      },
      expect: () => [isA<MobileMoneyPaymentEscrowed>()],
      verify: (_) {
        final calls = verify(
          () => analytics.logEvent(
            AnalyticsEvents.paymentSucceeded,
            properties: captureAny(named: 'properties'),
          ),
        ).captured;
        expect(calls, hasLength(1));
        final p = calls.single as Map<String, Object?>;
        expect(p['method'], 'mobile_money');
        expect(p['context'], 'bid_supplement');
        expect(p['currency'], 'XOF');
        expect(p.containsKey('amount_bracket'), isTrue);
        expect(p.keys, isNot(contains('phone')));
        expect(p.keys, isNot(contains('msisdn')));
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyConfirmed,
            properties: {'scope': 'bid_supplement'},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'dépôt refusé : payment_failed émis une fois, context bid_supplement',
      build: () {
        when(() => repository.getStatus(supplementScope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'ACCEPTED',
            paymentStatus: 'PENDING',
            amount: 1500,
            deposit: failedDeposit,
          ),
        );
        return bloc();
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(pending),
      act: (b) async {
        b.add(const MobileMoneyStatusPolled(scope: supplementScope));
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyStatusPolled(scope: supplementScope));
      },
      expect: () => [isA<MobileMoneyPaymentDepositFailed>()],
      verify: (_) {
        final calls = verify(
          () => analytics.logEvent(
            AnalyticsEvents.paymentFailed,
            properties: captureAny(named: 'properties'),
          ),
        ).captured;
        expect(calls, hasLength(1));
        final p = calls.single as Map<String, Object?>;
        expect(p['method'], 'mobile_money');
        expect(p['context'], 'bid_supplement');
        expect(p['reason'], 'declined');
        expect(p['error_code'], 'PAYER_NOT_FOUND');
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'initiation avec opérateur : portée supplément, analytics scope '
      'bid_supplement',
      build: () {
        when(
          () => repository.initiate(
            supplementScope,
            phoneNumber: null,
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            paymentStatus: 'PENDING',
            amount: 1500,
            deposit: liveDeposit,
          ),
        );
        return bloc();
      },
      act: (b) => b.add(
        const MobileMoneyPaymentInitiateRequested(
          scope: supplementScope,
          provider: 'ORANGE_CIV',
        ),
      ),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        final invocation =
            verify(
                  () => analytics.logEvent(
                    AnalyticsEvents.mobileMoneyInitiated,
                    properties: captureAny(named: 'properties'),
                  ),
                ).captured.single
                as Map<String, Object?>;
        expect(invocation['scope'], 'bid_supplement');
        expect(invocation['chosen'], isTrue);
      },
    );
  });

  group('portée modification de colis (A8)', () {
    const amendmentId = '880e8400-e29b-41d4-a716-446655440333';
    const amendmentScope = MobileMoneyScope.amendment(
      bidId: bidId,
      amendmentId: amendmentId,
    );
    const pending = MobileMoneyPaymentStatus(
      subjectId: bidId,
      subjectStatus: 'ACCEPTED',
      paymentStatus: 'PENDING',
      amount: 1500,
    );
    const failedDeposit = MobileMoneyDeposit(
      id: 'deposit-a',
      status: MobileMoneyDepositStatus.failed,
      providerLabel: 'Orange Money',
      failureCode: 'PAYER_NOT_FOUND',
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'paymentSucceeded_contextBidAmendment : payment_succeeded une fois, '
      'method mobile_money, context bid_amendment, sans PII',
      build: () {
        when(
          () => repository.getStatus(amendmentScope),
        ).thenAnswer((_) async => escrowedStatus);
        return bloc();
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(pending),
      act: (b) async {
        b.add(const MobileMoneyStatusPolled(scope: amendmentScope));
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyStatusPolled(scope: amendmentScope));
      },
      expect: () => [isA<MobileMoneyPaymentEscrowed>()],
      verify: (_) {
        final calls = verify(
          () => analytics.logEvent(
            AnalyticsEvents.paymentSucceeded,
            properties: captureAny(named: 'properties'),
          ),
        ).captured;
        expect(calls, hasLength(1));
        final p = calls.single as Map<String, Object?>;
        expect(p['method'], 'mobile_money');
        expect(p['context'], 'bid_amendment');
        expect(p['currency'], 'XOF');
        expect(p.containsKey('amount_bracket'), isTrue);
        expect(p.keys, isNot(contains('phone')));
        expect(p.keys, isNot(contains('msisdn')));
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyConfirmed,
            properties: {'scope': 'bid_amendment'},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'paymentFailed_contextBidAmendment : dépôt refusé, payment_failed une '
      'fois, context bid_amendment',
      build: () {
        when(() => repository.getStatus(amendmentScope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'ACCEPTED',
            paymentStatus: 'PENDING',
            amount: 1500,
            deposit: failedDeposit,
          ),
        );
        return bloc();
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(pending),
      act: (b) async {
        b.add(const MobileMoneyStatusPolled(scope: amendmentScope));
        await Future<void>.delayed(Duration.zero);
        b.add(const MobileMoneyStatusPolled(scope: amendmentScope));
      },
      expect: () => [isA<MobileMoneyPaymentDepositFailed>()],
      verify: (_) {
        final calls = verify(
          () => analytics.logEvent(
            AnalyticsEvents.paymentFailed,
            properties: captureAny(named: 'properties'),
          ),
        ).captured;
        expect(calls, hasLength(1));
        final p = calls.single as Map<String, Object?>;
        expect(p['method'], 'mobile_money');
        expect(p['context'], 'bid_amendment');
        expect(p['reason'], 'declined');
        expect(p['error_code'], 'PAYER_NOT_FOUND');
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'initiate_amendmentScope_analyticsScopeBidAmendment',
      build: () {
        when(
          () => repository.initiate(
            amendmentScope,
            phoneNumber: null,
            provider: 'ORANGE_CIV',
          ),
        ).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            paymentStatus: 'PENDING',
            amount: 1500,
            deposit: liveDeposit,
          ),
        );
        return bloc();
      },
      act: (b) => b.add(
        const MobileMoneyPaymentInitiateRequested(
          scope: amendmentScope,
          provider: 'ORANGE_CIV',
        ),
      ),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        final invocation =
            verify(
                  () => analytics.logEvent(
                    AnalyticsEvents.mobileMoneyInitiated,
                    properties: captureAny(named: 'properties'),
                  ),
                ).captured.single
                as Map<String, Object?>;
        expect(invocation['scope'], 'bid_amendment');
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'opened_noDeposit_amendment_readsAcceptedOperatorsOnScope',
      build: () {
        when(
          () => repository.getStatus(amendmentScope),
        ).thenAnswer((_) async => pending);
        when(
          () => repository.acceptedOperators(amendmentScope),
        ).thenAnswer((_) async => accepted);
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: amendmentScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        const MobileMoneyPaymentChoosePayer(
          status: pending,
          accepted: accepted,
        ),
      ],
      verify: (_) => verifyNoInitiate(),
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'opened_cancelledAmendment_isFinalExpired : ni choix du payeur ni '
      'dépôt relancé',
      build: () {
        when(() => repository.getStatus(amendmentScope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'ACCEPTED',
            paymentStatus: 'CANCELLED',
            amount: 1500,
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: amendmentScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentExpired>(),
      ],
      verify: (_) {
        verifyNoInitiate();
        verifyNever(() => repository.acceptedOperators(any()));
      },
    );

    for (final refunding in ['REFUND_PENDING', 'REFUNDED']) {
      blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        'opened_amendmentRefund_$refunding : fenêtre close, jamais un '
        'choix du payeur',
        build: () {
          when(() => repository.getStatus(amendmentScope)).thenAnswer(
            (_) async => MobileMoneyPaymentStatus(
              subjectId: bidId,
              paymentStatus: refunding,
              deadlineAt: DateTime.now().add(const Duration(hours: 1)),
              amount: 1500,
            ),
          );
          return bloc();
        },
        act: (b) =>
            b.add(const MobileMoneyPaymentOpened(scope: amendmentScope)),
        expect: () => [
          isA<MobileMoneyPaymentLoading>(),
          isA<MobileMoneyPaymentExpired>(),
        ],
      );
    }

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'opened_amendmentUnknownStatus_showsInProgress : statut inconnu, '
      'échéance à venir',
      build: () {
        when(() => repository.getStatus(amendmentScope)).thenAnswer(
          (_) async => MobileMoneyPaymentStatus(
            subjectId: bidId,
            paymentStatus: 'SOMETHING_NEW',
            deadlineAt: DateTime.now().add(const Duration(hours: 1)),
            amount: 1500,
          ),
        );
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: amendmentScope)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
    );
  });

  group(
    'refus immédiat de l\'opérateur à l\'initiation (422 deposit-rejected)',
    () {
      const rejected = ValidationException(
        'Paiement refusé par l\'opérateur',
        code: 'mobile-money-deposit-rejected',
      );

      void stubRejected({String? phone, String? provider}) => when(
        () => repository.initiate(
          scope,
          phoneNumber: phone ?? '+2250707070707',
          provider: provider ?? 'ORANGE_CIV',
        ),
      ).thenThrow(rejected);

      blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        'le statut relu montre le dépôt refusé : DepositFailed (motif traduit '
        'porté par le dépôt), renvoi possible, mobile_money_failed stage '
        'initiate une seule fois',
        build: () {
          stubRejected();
          when(
            () => repository.getStatus(scope),
          ).thenAnswer((_) async => failedStatus);
          return bloc();
        },
        seed: () => const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: accepted,
        ),
        act: (b) => b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ),
        expect: () => [
          const MobileMoneyPaymentChoosePayer(
            status: noDepositStatus,
            accepted: accepted,
            isSubmitting: true,
          ),
          const MobileMoneyPaymentDepositFailed(failedStatus),
        ],
        verify: (b) {
          expect(b.canResend, isTrue);
          verify(
            () => analytics.logEvent(
              AnalyticsEvents.mobileMoneyFailed,
              properties: {
                'failure_code': 'mobile-money-deposit-rejected',
                'stage': 'initiate',
                'scope': 'bid',
              },
            ),
          ).called(1);
          // Pas de second event d'échec (celui du sondage) ni de succès.
          verifyNever(
            () => analytics.logEvent(
              AnalyticsEvents.mobileMoneyFailed,
              properties: {
                'failure_code': 'INSUFFICIENT_FUNDS',
                'scope': 'bid',
              },
            ),
          );
          verifyNever(
            () => analytics.logEvent(
              AnalyticsEvents.mobileMoneyInitiated,
              properties: any(named: 'properties'),
            ),
          );
        },
      );

      blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        '« Renvoyer une demande » après ce refus : même numéro et même '
        'opérateur, nouveau dépôt vivant',
        build: () {
          var calls = 0;
          when(
            () => repository.initiate(
              scope,
              phoneNumber: '+2250707070707',
              provider: 'ORANGE_CIV',
            ),
          ).thenAnswer((_) async {
            if (calls++ == 0) throw rejected;
            return liveStatus;
          });
          when(
            () => repository.getStatus(scope),
          ).thenAnswer((_) async => failedStatus);
          return bloc();
        },
        seed: () => const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: accepted,
        ),
        act: (b) async {
          b.add(
            const MobileMoneyPaymentInitiateRequested(
              scope: scope,
              phoneNumber: '+2250707070707',
              provider: 'ORANGE_CIV',
            ),
          );
          await pumpEventQueue();
          b.add(const MobileMoneyPaymentResendRequested(scope: scope));
        },
        expect: () => [
          isA<MobileMoneyPaymentChoosePayer>().having(
            (s) => s.isSubmitting,
            'isSubmitting',
            isTrue,
          ),
          const MobileMoneyPaymentDepositFailed(failedStatus),
          isA<MobileMoneyPaymentLoading>(),
          const MobileMoneyPaymentAwaitingConfirmation(liveStatus),
        ],
        verify: (_) {
          verify(
            () => repository.initiate(
              scope,
              phoneNumber: '+2250707070707',
              provider: 'ORANGE_CIV',
            ),
          ).called(2);
        },
      );

      blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        'relecture en échec : repli sur le choix du payeur avec le bandeau '
        'd\'erreur, pas de renvoi, mobile_money_failed une seule fois',
        build: () {
          stubRejected();
          when(
            () => repository.getStatus(scope),
          ).thenThrow(Exception('réseau'));
          return bloc();
        },
        seed: () => const MobileMoneyPaymentChoosePayer(
          status: noDepositStatus,
          accepted: accepted,
        ),
        act: (b) => b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ),
        expect: () => [
          const MobileMoneyPaymentChoosePayer(
            status: noDepositStatus,
            accepted: accepted,
            isSubmitting: true,
          ),
          isA<MobileMoneyPaymentChoosePayer>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having(
                (s) => s.error,
                'error',
                isA<ValidationException>().having(
                  (e) => e.code,
                  'code',
                  'mobile-money-deposit-rejected',
                ),
              ),
        ],
        verify: (b) {
          expect(b.canResend, isFalse);
          verify(
            () => analytics.logEvent(
              AnalyticsEvents.mobileMoneyFailed,
              properties: {
                'failure_code': 'mobile-money-deposit-rejected',
                'stage': 'initiate',
                'scope': 'bid',
              },
            ),
          ).called(1);
        },
      );

      blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        'relecture sans dépôt refusé : même repli sur le choix du payeur',
        build: () {
          stubRejected();
          when(
            () => repository.getStatus(scope),
          ).thenAnswer((_) async => noDepositStatus);
          return bloc();
        },
        seed: () =>
            const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
        act: (b) => b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ),
        expect: () => [
          const MobileMoneyPaymentChoosePayer(
            status: noDepositStatus,
            isSubmitting: true,
          ),
          isA<MobileMoneyPaymentChoosePayer>().having(
            (s) => s.error,
            'error',
            isA<ValidationException>(),
          ),
        ],
        verify: (b) => expect(b.canResend, isFalse),
      );

      blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        'un autre 422 ne relit pas le statut',
        build: () {
          when(
            () => repository.initiate(
              scope,
              phoneNumber: '+2250707070707',
              provider: 'ORANGE_CIV',
            ),
          ).thenThrow(
            const ValidationException('x', code: 'mobile-money-invalid-phone'),
          );
          return bloc();
        },
        seed: () =>
            const MobileMoneyPaymentChoosePayer(status: noDepositStatus),
        act: (b) => b.add(
          const MobileMoneyPaymentInitiateRequested(
            scope: scope,
            phoneNumber: '+2250707070707',
            provider: 'ORANGE_CIV',
          ),
        ),
        expect: () => [
          isA<MobileMoneyPaymentChoosePayer>(),
          isA<MobileMoneyPaymentChoosePayer>().having(
            (s) => s.error,
            'error',
            isNotNull,
          ),
        ],
        verify: (_) => verifyNever(() => repository.getStatus(any())),
      );
    },
  );

  group('sondage pendant la lecture d\'ouverture', () {
    const residual = MobileMoneyPaymentStatus(
      subjectId: threadId,
      paymentStatus: 'CANCELLED',
      amount: 50.0,
    );

    for (final entry in <String, MobileMoneyPaymentState>{
      'Initial': const MobileMoneyPaymentInitial(),
      'Loading': const MobileMoneyPaymentLoading(),
    }.entries) {
      blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        'ligne CANCELLED résiduelle d\'un fil en ${entry.key} : le sondage '
        'est ignoré (ni Expired, ni analytics d\'expiration)',
        build: () {
          when(
            () => repository.getStatus(negotiationScope),
          ).thenAnswer((_) async => residual);
          return bloc();
        },
        seed: () => entry.value,
        act: (b) =>
            b.add(const MobileMoneyStatusPolled(scope: negotiationScope)),
        expect: () => [],
        verify: (_) {
          verifyNever(
            () => analytics.logEvent(
              AnalyticsEvents.mobileMoneyExpired,
              properties: any(named: 'properties'),
            ),
          );
          verifyNever(
            () => analytics.logEvent(
              AnalyticsEvents.paymentFailed,
              properties: any(named: 'properties'),
            ),
          );
        },
      );
    }

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture lente : sondage résiduel pendant les opérateurs acceptés, '
      'seul Loading est émis (jamais Expired)',
      build: () {
        final slow = Completer<MobileMoneyAcceptedOperators?>();
        addTearDown(() {
          if (!slow.isCompleted) slow.complete(accepted);
        });
        when(
          () => repository.getStatus(negotiationScope),
        ).thenAnswer((_) async => residual);
        when(
          () => repository.acceptedOperators(negotiationScope),
        ).thenAnswer((_) => slow.future.then((_) => accepted));
        return bloc();
      },
      act: (b) async {
        b.add(const MobileMoneyPaymentOpened(scope: negotiationScope));
        await pumpEventQueue();
        b.add(const MobileMoneyStatusPolled(scope: negotiationScope));
        await pumpEventQueue();
      },
      expect: () => [isA<MobileMoneyPaymentLoading>()],
      verify: (_) {
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyExpired,
            properties: any(named: 'properties'),
          ),
        );
      },
    );
  });
}
