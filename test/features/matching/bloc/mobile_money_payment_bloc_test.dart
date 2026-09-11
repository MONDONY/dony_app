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
      'aucun dépôt : initiate appelé une fois, analytics mobileMoneyInitiated',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.initiate(scope),
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
        verify(() => repository.initiate(scope)).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.mobileMoneyInitiated,
            properties: {'provider': 'Wave', 'wave': true, 'scope': 'bid'},
          ),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'ouverture avec un numéro payeur et sans dépôt vivant : initiate reçoit '
      'ce numéro',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.initiate(scope, phoneNumber: '+221771234567'),
        ).thenAnswer((_) async => liveStatus);
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
        isA<MobileMoneyPaymentAwaitingConfirmation>(),
      ],
      verify: (_) {
        verify(
          () => repository.initiate(scope, phoneNumber: '+221771234567'),
        ).called(1);
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
          () => repository.initiate(negotiationScope),
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
              'wave': true,
              'scope': 'negotiation',
            },
          ),
        ).called(1);
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
      'initiate en échec après un statut sans dépôt → Error',
      build: () {
        when(
          () => repository.getStatus(scope),
        ).thenAnswer((_) async => noDepositStatus);
        when(
          () => repository.initiate(scope),
        ).thenThrow(const ServerException());
        return bloc();
      },
      act: (b) => b.add(const MobileMoneyPaymentOpened(scope: scope)),
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

  group('MobileMoneyPaymentInitiateRequested', () {
    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'numéro transmis au repository, résultat mappé, analytics '
      'mobileMoneyInitiated',
      build: () {
        when(
          () => repository.initiate(scope, phoneNumber: '+221771234567'),
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
          () => repository.initiate(scope, phoneNumber: '+221771234567'),
        ).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'sans numéro : repository appelé sans phoneNumber',
      build: () {
        when(
          () => repository.initiate(scope),
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
        verify(() => repository.initiate(scope)).called(1);
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'échec → Error',
      build: () {
        when(
          () => repository.initiate(scope),
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
