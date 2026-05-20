import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/profile/data/traveler_upgrade_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late TravelerUpgradeRepository repo;

  const path = '/users/me/roles/traveler/activate';
  const deactivatePath = '/users/me/roles/traveler';

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repo = TravelerUpgradeRepository(mockClient);
  });

  group('activateTravelerRole', () {
    test('retourne UserModel quand le serveur répond 200', () async {
      when(() => mockDio.post<Map<String, dynamic>>(path))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: path),
                data: {
                  'id': 'user-123',
                  'roles': ['SENDER', 'TRAVELER'],
                  'kycStatus': 'VERIFIED',
                  'stripeAccountStatus': 'ONBOARDING_COMPLETE',
                  'status': 'ACTIVE',
                },
              ));

      final user = await repo.activateTravelerRole();

      expect(user.id, 'user-123');
      expect(user.roles, containsAll(['SENDER', 'TRAVELER']));
      expect(user.kycStatus, 'VERIFIED');
      expect(user.stripeAccountStatus, 'ONBOARDING_COMPLETE');
    });

    test('lève NetworkException quand response.data est null', () async {
      when(() => mockDio.post<Map<String, dynamic>>(path))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: path),
              ));

      await expectLater(
        repo.activateTravelerRole(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('lève ConflictException quand le serveur renvoie 409', () async {
      when(() => mockDio.post<Map<String, dynamic>>(path)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: path),
          error: const ConflictException('KYC ou Stripe non complété'),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repo.activateTravelerRole(),
        throwsA(isA<ConflictException>()),
      );
    });

    test('lève AppException sur erreur réseau', () async {
      when(() => mockDio.post<Map<String, dynamic>>(path)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: path),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(
        repo.activateTravelerRole(),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('deactivateTravelerRole', () {
    test('retourne UserModel sans TRAVELER quand le serveur répond 200',
        () async {
      when(() => mockDio.delete<Map<String, dynamic>>(deactivatePath))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: deactivatePath),
                data: {
                  'id': 'user-123',
                  'roles': ['SENDER'],
                  'kycStatus': 'VERIFIED',
                  'stripeAccountStatus': 'ONBOARDING_COMPLETE',
                  'status': 'ACTIVE',
                },
              ));

      final user = await repo.deactivateTravelerRole();

      expect(user.id, 'user-123');
      expect(user.roles, contains('SENDER'));
      expect(user.roles, isNot(contains('TRAVELER')));
      expect(user.kycStatus, 'VERIFIED');
      expect(user.stripeAccountStatus, 'ONBOARDING_COMPLETE');
    });

    test('lève NetworkException quand response.data est null', () async {
      when(() => mockDio.delete<Map<String, dynamic>>(deactivatePath))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: deactivatePath),
              ));

      await expectLater(
        repo.deactivateTravelerRole(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('lève AppException sur erreur réseau', () async {
      when(() => mockDio.delete<Map<String, dynamic>>(deactivatePath))
          .thenThrow(
        DioException(
          requestOptions: RequestOptions(path: deactivatePath),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(
        repo.deactivateTravelerRole(),
        throwsA(isA<AppException>()),
      );
    });
  });
}
