import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:dony/features/matching/data/models/mobile_money_accepted_operators.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMobileMoneyRemoteDatasource extends Mock
    implements MobileMoneyRemoteDatasource {}

void main() {
  late MockMobileMoneyRemoteDatasource datasource;
  late MobileMoneyRepository repository;

  const bidId = '550e8400-e29b-41d4-a716-446655440000';
  const scope = MobileMoneyScope.bid(bidId);

  const pendingStatus = MobileMoneyPaymentStatus(
    subjectId: bidId,
    subjectStatus: 'AWAITING_PAYMENT',
    paymentStatus: 'PENDING',
    amount: 50.0,
  );

  setUp(() {
    datasource = MockMobileMoneyRemoteDatasource();
    repository = MobileMoneyRepository(datasource);
  });

  group('MobileMoneyRepository', () {
    group('getStatus', () {
      test('délègue à datasource.getStatus et renvoie le statut', () async {
        when(
          () => datasource.getStatus(scope),
        ).thenAnswer((_) async => pendingStatus);

        final result = await repository.getStatus(scope);

        verify(() => datasource.getStatus(scope)).called(1);
        expect(result, equals(pendingStatus));
        expect(result.paymentStatus, 'PENDING');
      });

      test('propage l\'exception du datasource', () async {
        when(
          () => datasource.getStatus(scope),
        ).thenAnswer((_) => Future.error(Exception('Network error')));

        await expectLater(
          repository.getStatus(scope),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('acceptedOperators', () {
      const operators = MobileMoneyAcceptedOperators(
        currency: 'XOF',
        travelerFirstName: 'Awa',
        providers: {'ORANGE_CIV', 'MTN_MOMO_CIV'},
      );

      test('repository_acceptedOperators_200', () async {
        when(
          () => datasource.acceptedOperators(scope),
        ).thenAnswer((_) async => operators);

        final result = await repository.acceptedOperators(scope);

        verify(() => datasource.acceptedOperators(scope)).called(1);
        expect(result, equals(operators));
      });

      test('repository_acceptedOperators_404_returnsNull', () async {
        // Ancien back : la route n'existe pas encore.
        when(() => datasource.acceptedOperators(scope)).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            error: const NotFoundException(),
          ),
        );

        expect(await repository.acceptedOperators(scope), isNull);
      });

      test('404 déjà converti en NotFoundException : null aussi', () async {
        when(
          () => datasource.acceptedOperators(scope),
        ).thenAnswer((_) => Future.error(const NotFoundException()));

        expect(await repository.acceptedOperators(scope), isNull);
      });

      test('autre erreur : propagée', () async {
        when(
          () => datasource.acceptedOperators(scope),
        ).thenAnswer((_) => Future.error(const ForbiddenException()));

        await expectLater(
          repository.acceptedOperators(scope),
          throwsA(isA<ForbiddenException>()),
        );
      });
    });

    group('initiate', () {
      test('délègue à datasource.initiate sans phoneNumber', () async {
        when(
          () => datasource.initiate(scope),
        ).thenAnswer((_) async => pendingStatus);

        final result = await repository.initiate(scope);

        verify(() => datasource.initiate(scope)).called(1);
        expect(result, equals(pendingStatus));
      });

      test('délègue à datasource.initiate avec phoneNumber', () async {
        when(
          () => datasource.initiate(scope, phoneNumber: '+221771234567'),
        ).thenAnswer((_) async => pendingStatus);

        final result = await repository.initiate(
          scope,
          phoneNumber: '+221771234567',
        );

        verify(
          () => datasource.initiate(scope, phoneNumber: '+221771234567'),
        ).called(1);
        expect(result, equals(pendingStatus));
      });

      test('délègue à datasource.initiate avec provider', () async {
        when(
          () => datasource.initiate(scope, provider: 'ORANGE_SEN'),
        ).thenAnswer((_) async => pendingStatus);

        final result = await repository.initiate(scope, provider: 'ORANGE_SEN');

        verify(
          () => datasource.initiate(scope, provider: 'ORANGE_SEN'),
        ).called(1);
        expect(result, equals(pendingStatus));
      });

      test(
        'délègue à datasource.initiate avec phoneNumber et provider',
        () async {
          when(
            () => datasource.initiate(
              scope,
              phoneNumber: '+221771234567',
              provider: 'WAVE_SEN',
            ),
          ).thenAnswer((_) async => pendingStatus);

          final result = await repository.initiate(
            scope,
            phoneNumber: '+221771234567',
            provider: 'WAVE_SEN',
          );

          verify(
            () => datasource.initiate(
              scope,
              phoneNumber: '+221771234567',
              provider: 'WAVE_SEN',
            ),
          ).called(1);
          expect(result, equals(pendingStatus));
        },
      );

      test('propage l\'exception du datasource', () async {
        when(
          () => datasource.initiate(scope),
        ).thenAnswer((_) => Future.error(Exception('403 Forbidden')));

        await expectLater(
          repository.initiate(scope),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
