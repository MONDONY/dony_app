import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_remote_datasource.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, [String path = '/traveler-status/me']) =>
    Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

const _eligibilityPath = '/travelers/me/publishing-eligibility';

DioException _failure({
  int? status,
  AppException? error,
  DioExceptionType? type,
}) => DioException(
  requestOptions: RequestOptions(path: _eligibilityPath),
  type: type ?? DioExceptionType.badResponse,
  response: status == null
      ? null
      : Response(
          statusCode: status,
          requestOptions: RequestOptions(path: _eligibilityPath),
        ),
  error: error,
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

  group('declareIndividual', () {
    test('envoie le statut et la confirmation, rien d\'autre', () async {
      when(
        () => dio.put('/traveler-status/me', data: any(named: 'data')),
      ).thenAnswer(
        (_) async =>
            _ok({'status': 'INDIVIDUAL', 'declaredAt': '2026-11-10T10:00:00Z'}),
      );

      final declared = await repository.declareIndividual();

      final body =
          verify(
                () => dio.put(
                  '/traveler-status/me',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body, {'status': 'INDIVIDUAL', 'personalUseConfirmed': true});
      expect(declared.status, TravelerStatus.individual);
      expect(declared.declaredAt, DateTime.utc(2026, 11, 10, 10));
    });

    test('l\'erreur du back remonte telle quelle', () async {
      when(
        () => dio.put('/traveler-status/me', data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/traveler-status/me'),
        ),
      );

      expect(repository.declareIndividual(), throwsA(isA<DioException>()));
    });
  });

  group('éligibilité à la publication', () {
    test(
      'fetchEligibility lit GET /travelers/me/publishing-eligibility',
      () async {
        when(() => dio.get(_eligibilityPath)).thenAnswer(
          (_) async => _ok({
            'allowed': false,
            'reason': 'STATUS_REQUIRED',
            'limit': 4,
            'used': 4,
            'resetsOn': '2026-12-01',
            'travelerStatus': null,
          }, _eligibilityPath),
        );

        final e = await repository.fetchEligibility();

        expect(e.reason, PublishingReason.statusRequired);
        expect(e.limit, 4);
      },
    );

    test('check : réponse lue, aucun échec', () async {
      when(() => dio.get(_eligibilityPath)).thenAnswer(
        (_) async => _ok({'allowed': true, 'reason': 'OK'}, _eligibilityPath),
      );

      final result = await repository.checkEligibility();

      expect(result.eligibility.allowed, isTrue);
      expect(result.failureCode, isNull);
    });

    test('check : 404 (ancien back) = OK, sans échec à tracer', () async {
      when(() => dio.get(_eligibilityPath)).thenThrow(_failure(status: 404));

      final result = await repository.checkEligibility();

      expect(result.eligibility, PublishingEligibility.ok);
      expect(result.failureCode, isNull);
    });

    test('check : 404 déjà converti par l\'intercepteur = OK', () async {
      when(
        () => dio.get(_eligibilityPath),
      ).thenThrow(_failure(error: const NotFoundException()));

      final result = await repository.checkEligibility();

      expect(result.eligibility.allowed, isTrue);
      expect(result.failureCode, isNull);
    });

    test('check : erreur réseau = OK, avec le code à tracer', () async {
      when(
        () => dio.get(_eligibilityPath),
      ).thenThrow(_failure(type: DioExceptionType.connectionError));

      final result = await repository.checkEligibility();

      expect(result.eligibility.allowed, isTrue);
      expect(result.failureCode, isNotNull);
    });

    test('check : erreur 500 = OK, avec le code à tracer', () async {
      when(
        () => dio.get(_eligibilityPath),
      ).thenThrow(_failure(status: 500, error: const ServerException('boom')));

      final result = await repository.checkEligibility();

      expect(result.eligibility.allowed, isTrue);
      expect(result.failureCode, isNotNull);
    });

    test('check : erreur non réseau (réponse illisible) = OK', () async {
      when(
        () => dio.get(_eligibilityPath),
      ).thenAnswer((_) async => _ok('pas du json', _eligibilityPath));

      final result = await repository.checkEligibility();

      expect(result.eligibility.allowed, isTrue);
      expect(result.failureCode, 'unknown');
    });
  });
}
