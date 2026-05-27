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
  });
}
