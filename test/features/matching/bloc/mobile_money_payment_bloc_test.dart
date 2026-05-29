import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_model.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';

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
      'MobileMoneyStatusPolled → MobileMoneyPaymentPending quand status=PENDING',
      build: () {
        when(() => repo.getStatus(bidId))
            .thenAnswer((_) async => const MobileMoneyPaymentModel(
              id: 'id-1',
              status: 'PENDING',
              paymentLink: 'https://wave.test/pay?ref=abc',
              amount: 50.0,
              currency: 'XOF',
            ));
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentPending>()
            .having((s) => s.paymentLink, 'paymentLink', contains('wave.test')),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled → MobileMoneyPaymentConfirmed quand status=COMPLETED',
      build: () {
        when(() => repo.getStatus(bidId))
            .thenAnswer((_) async => const MobileMoneyPaymentModel(
              id: 'id-2',
              status: 'COMPLETED',
              amount: 50.0,
              currency: 'XOF',
            ));
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
      'MobileMoneyStatusPolled → MobileMoneyPaymentExpired quand status=EXPIRED',
      build: () {
        when(() => repo.getStatus(bidId)).thenAnswer((_) async =>
            const MobileMoneyPaymentModel(
              id: 'id-3',
              status: 'EXPIRED',
              amount: 50.0,
              currency: 'XOF',
            ));
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentExpired>(),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled → MobileMoneyPaymentError quand status=FAILED',
      build: () {
        when(() => repo.getStatus(bidId)).thenAnswer((_) async =>
            const MobileMoneyPaymentModel(
              id: 'id-4',
              status: 'FAILED',
              amount: 50.0,
              currency: 'XOF',
              failureReason: 'Solde insuffisant',
            ));
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentError>()
            .having((s) => s.message, 'message', 'Solde insuffisant'),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyLinkRegenRequested → MobileMoneyPaymentPending avec nouveau lien',
      build: () {
        when(() => repo.regenerateLink(bidId)).thenAnswer((_) async =>
            const MobileMoneyPaymentModel(
              id: 'id-5',
              status: 'PENDING',
              amount: 50.0,
              currency: 'XOF',
              paymentLink: 'https://wave.test/pay?ref=new',
            ));
        return bloc;
      },
      act: (b) => b.add(const MobileMoneyLinkRegenRequested(bidId: bidId)),
      expect: () => [
        isA<MobileMoneyPaymentLoading>(),
        isA<MobileMoneyPaymentPending>()
            .having((s) => s.paymentLink, 'paymentLink', contains('ref=new')),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled depuis état Pending → pas de Loading (pas de clignotement)',
      build: () {
        // Server returns COMPLETED — so a state change DOES happen, but no Loading first
        when(() => repo.getStatus(bidId))
            .thenAnswer((_) async => const MobileMoneyPaymentModel(
              id: 'id-6',
              status: 'COMPLETED',
              amount: 50.0,
              currency: 'XOF',
            ));
        return bloc;
      },
      seed: () => const MobileMoneyPaymentPending(
        paymentLink: 'https://wave.test/pay?ref=abc',
      ),
      act: (b) => b.add(const MobileMoneyStatusPolled(bidId: bidId)),
      expect: () => [
        // No MobileMoneyPaymentLoading emitted — periodic poll skips spinner
        isA<MobileMoneyPaymentConfirmed>(),
      ],
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'MobileMoneyStatusPolled depuis état Error → Loading émis (première tentative après erreur)',
      build: () {
        when(() => repo.getStatus(bidId))
            .thenAnswer((_) async => const MobileMoneyPaymentModel(
              id: 'id-7',
              status: 'PENDING',
              paymentLink: 'https://wave.test/pay?ref=abc',
              amount: 50.0,
              currency: 'XOF',
            ));
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
