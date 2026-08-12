import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_model.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMobileMoneyRemoteDatasource extends Mock
    implements MobileMoneyRemoteDatasource {}

void main() {
  late MockMobileMoneyRemoteDatasource datasource;
  late MobileMoneyRepository repository;

  const bidId = '550e8400-e29b-41d4-a716-446655440000';

  const _pendingModel = MobileMoneyPaymentModel(
    id: 'payment-id-1',
    status: 'PENDING',
    amount: 50.0,
    currency: 'XOF',
    paymentLink: 'https://wave.test/pay?ref=abc',
  );

  const _completedModel = MobileMoneyPaymentModel(
    id: 'payment-id-2',
    status: 'COMPLETED',
    amount: 50.0,
    currency: 'XOF',
  );

  setUp(() {
    datasource = MockMobileMoneyRemoteDatasource();
    repository = MobileMoneyRepository(datasource);
  });

  group('MobileMoneyRepository', () {
    group('getStatus', () {
      test('delegates to datasource.getStatus and returns model', () async {
        when(
          () => datasource.getStatus(bidId),
        ).thenAnswer((_) async => _pendingModel);

        final result = await repository.getStatus(bidId);

        verify(() => datasource.getStatus(bidId)).called(1);
        expect(result, equals(_pendingModel));
        expect(result.status, 'PENDING');
      });

      test('propagates exception from datasource', () async {
        when(
          () => datasource.getStatus(bidId),
        ).thenAnswer((_) => Future.error(Exception('Network error')));

        await expectLater(
          repository.getStatus(bidId),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('regenerateLink', () {
      test(
        'delegates to datasource.regenerateLink and returns model',
        () async {
          when(
            () => datasource.regenerateLink(bidId),
          ).thenAnswer((_) async => _completedModel);

          final result = await repository.regenerateLink(bidId);

          verify(() => datasource.regenerateLink(bidId)).called(1);
          expect(result, equals(_completedModel));
          expect(result.status, 'COMPLETED');
        },
      );

      test('propagates exception from datasource', () async {
        when(
          () => datasource.regenerateLink(bidId),
        ).thenAnswer((_) => Future.error(Exception('403 Forbidden')));

        await expectLater(
          repository.regenerateLink(bidId),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
