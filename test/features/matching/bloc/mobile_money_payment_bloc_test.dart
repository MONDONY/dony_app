import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMobileMoneyRepository extends Mock implements MobileMoneyRepository {}

void main() {
  group('MobileMoneyPaymentBloc', () {
    late MockMobileMoneyRepository repo;
    late MobileMoneyPaymentBloc bloc;
    const bidId = '550e8400-e29b-41d4-a716-446655440000';

    setUp(() {
      repo = MockMobileMoneyRepository();
      bloc = MobileMoneyPaymentBloc(repo);
    });

    tearDown(() => bloc.close());

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled → MobileMoneyPaymentPending quand le paiement n\'est ni séquestré ni expiré',
      build: () {
        when(() => repo.getStatus(bidId)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            bidId: bidId,
            bidStatus: 'AWAITING_PAYMENT',
            paymentStatus: 'PENDING',
            amount: 50.0,
            deposit: MobileMoneyDeposit(
              id: 'deposit-1',
              status: MobileMoneyDepositStatus.accepted,
              authorizationUrl: 'https://wave.test/pay?ref=abc',
            ),
          ),
        );
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentPending>().having(
          (s) => s.paymentLink,
          'paymentLink',
          contains('wave.test'),
        ),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled → MobileMoneyPaymentConfirmed quand paymentStatus=ESCROW',
      build: () {
        when(() => repo.getStatus(bidId)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            bidId: bidId,
            bidStatus: 'ACCEPTED',
            paymentStatus: 'ESCROW',
            amount: 50.0,
          ),
        );
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentConfirmed>(),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled → MobileMoneyPaymentError si exception réseau',
      build: () {
        when(() => repo.getStatus(bidId)).thenThrow(Exception('network error'));
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>(),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled → MobileMoneyPaymentExpired quand le bid est annulé',
      build: () {
        when(() => repo.getStatus(bidId)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            bidId: bidId,
            bidStatus: 'CANCELLED',
            amount: 50.0,
          ),
        );
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentExpired>(),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled → MobileMoneyPaymentError quand le dernier dépôt a échoué',
      build: () {
        when(() => repo.getStatus(bidId)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            bidId: bidId,
            bidStatus: 'AWAITING_PAYMENT',
            amount: 50.0,
            deposit: MobileMoneyDeposit(
              id: 'deposit-1',
              status: MobileMoneyDepositStatus.failed,
              failureMessage: 'Solde insuffisant',
            ),
          ),
        );
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>().having(
          (s) => s.message,
          'message',
          'Solde insuffisant',
        ),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyLinkRegenRequested → MobileMoneyPaymentPending avec nouveau lien',
      build: () {
        when(() => repo.initiate(bidId)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            bidId: bidId,
            bidStatus: 'AWAITING_PAYMENT',
            paymentStatus: 'PENDING',
            amount: 50.0,
            deposit: MobileMoneyDeposit(
              id: 'deposit-2',
              status: MobileMoneyDepositStatus.accepted,
              authorizationUrl: 'https://wave.test/pay?ref=new',
            ),
          ),
        );
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyLinkRegenRequested(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentPending>().having(
          (s) => s.paymentLink,
          'paymentLink',
          contains('ref=new'),
        ),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled depuis état Pending → pas de Loading (pas de clignotement)',
      build: () {
        // Le serveur renvoie ESCROW — un changement d'état a bien lieu, mais sans Loading avant.
        when(() => repo.getStatus(bidId)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            bidId: bidId,
            bidStatus: 'ACCEPTED',
            paymentStatus: 'ESCROW',
            amount: 50.0,
          ),
        );
        return bloc;
      },
      seed: () => const MobileMoneyPaymentPending(
        paymentLink: 'https://wave.test/pay?ref=abc',
      ),
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        // Pas de MobileMoneyPaymentLoading émis — le poll périodique saute le spinner.
        isA<MobileMoneyPaymentConfirmed>(),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled depuis état Error → Loading émis (première tentative après erreur)',
      build: () {
        when(() => repo.getStatus(bidId)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            bidId: bidId,
            bidStatus: 'AWAITING_PAYMENT',
            paymentStatus: 'PENDING',
            amount: 50.0,
            deposit: MobileMoneyDeposit(
              id: 'deposit-3',
              status: MobileMoneyDepositStatus.accepted,
              authorizationUrl: 'https://wave.test/pay?ref=abc',
            ),
          ),
        );
        return bloc;
      },
      seed: () => const MobileMoneyPaymentError('previous error'),
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentPending>(),
      ],
    );
  });
}
