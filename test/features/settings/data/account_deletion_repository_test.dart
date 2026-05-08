import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late AccountDeletionRepository repo;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repo = AccountDeletionRepository(mockClient);
  });

  group('requestDeletion', () {
    test('completes when DELETE /auth/me returns 204', () async {
      when(() => mockDio.delete<dynamic>('/auth/me'))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/me'),
                statusCode: 204,
              ));

      await expectLater(repo.requestDeletion(), completes);
    });

    test('throws ValidationException when 422', () async {
      when(() => mockDio.delete<dynamic>('/auth/me')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/me'),
          error: const ValidationException('active-transactions'),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repo.requestDeletion(),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('reactivateAccount', () {
    test('returns UserModel on success', () async {
      when(() => mockDio.post<dynamic>('/auth/me/reactivate'))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/me/reactivate'),
                statusCode: 200,
                data: {
                  'id': 'u1',
                  'roles': ['SENDER'],
                  'kycStatus': 'PENDING',
                  'status': 'ACTIVE',
                },
              ));

      final user = await repo.reactivateAccount();
      expect(user.id, 'u1');
      expect(user.status, 'ACTIVE');
    });

    test('throws AppException on network error', () async {
      when(() => mockDio.post<dynamic>('/auth/me/reactivate')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/me/reactivate'),
          error: const NetworkException('Network error'),
          type: DioExceptionType.unknown,
        ),
      );

      await expectLater(
        repo.reactivateAccount(),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('deleteImmediately', () {
    test('appelle POST /auth/me/delete-immediately avec confirmationAcknowledged true', () async {
      when(() => mockDio.post<dynamic>(
            '/auth/me/delete-immediately',
            data: {'confirmationAcknowledged': true},
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/auth/me/delete-immediately'),
            statusCode: 204,
          ));

      await expectLater(repo.deleteImmediately(), completes);

      verify(() => mockDio.post<dynamic>(
            '/auth/me/delete-immediately',
            data: {'confirmationAcknowledged': true},
          )).called(1);
    });

    test('throws AppException on network error', () async {
      when(() => mockDio.post<dynamic>(
            '/auth/me/delete-immediately',
            data: {'confirmationAcknowledged': true},
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/me/delete-immediately'),
          error: const NetworkException('Network error'),
          type: DioExceptionType.unknown,
        ),
      );

      await expectLater(
        repo.deleteImmediately(),
        throwsA(isA<AppException>()),
      );
    });
  });
}
