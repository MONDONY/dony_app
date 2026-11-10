import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_remote_datasource.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: '/traveler-status/me'),
);

void main() {
  late MockApiClient client;
  late MockDio dio;
  late TravelerStatusRepository repository;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = TravelerStatusRepository(
      TravelerStatusRemoteDatasource(client),
    );
  });

  Map<String, dynamic> sentBody() =>
      verify(
            () =>
                dio.put('/traveler-status/me', data: captureAny(named: 'data')),
          ).captured.single
          as Map<String, dynamic>;

  test(
    'particulier : envoie le statut et la confirmation, rien d\'autre',
    () async {
      when(
        () => dio.put('/traveler-status/me', data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _ok({
          'status': 'INDIVIDUAL',
          'declaredAt': '2026-11-10T10:00:00Z',
          'businessName': null,
          'registrationNumber': null,
          'country': null,
        }),
      );

      final declared = await repository.declare(
        status: TravelerStatus.individual,
        personalUseConfirmed: true,
      );

      expect(sentBody(), {
        'status': 'INDIVIDUAL',
        'personalUseConfirmed': true,
      });
      expect(declared.status, TravelerStatus.individual);
      expect(declared.declaredAt, DateTime.utc(2026, 11, 10, 10));
      expect(declared.registrationNumber, isNull);
    },
  );

  test(
    'professionnel : envoie raison sociale, numéro et pays nettoyés',
    () async {
      when(
        () => dio.put('/traveler-status/me', data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _ok({
          'status': 'PROFESSIONAL',
          'declaredAt': '2026-11-10T10:00:00Z',
          'businessName': 'Diallo Express SARL',
          'registrationNumber': 'CI-ABJ-2021-B-12345',
          'country': 'CI',
        }),
      );

      final declared = await repository.declare(
        status: TravelerStatus.professional,
        businessName: '  Diallo Express SARL ',
        registrationNumber: ' CI-ABJ-2021-B-12345 ',
        country: 'CI',
      );

      expect(sentBody(), {
        'status': 'PROFESSIONAL',
        'businessName': 'Diallo Express SARL',
        'registrationNumber': 'CI-ABJ-2021-B-12345',
        'country': 'CI',
      });
      expect(declared.status, TravelerStatus.professional);
      expect(declared.businessName, 'Diallo Express SARL');
      expect(declared.country, 'CI');
    },
  );

  test('l\'erreur du back remonte telle quelle', () async {
    when(
      () => dio.put('/traveler-status/me', data: any(named: 'data')),
    ).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/traveler-status/me')),
    );

    expect(
      () => repository.declare(
        status: TravelerStatus.individual,
        personalUseConfirmed: true,
      ),
      throwsA(isA<DioException>()),
    );
  });
}
