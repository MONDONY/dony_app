import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/cancellation/data/datasources/cancellation_remote_datasource.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

class _MockDatasource extends Mock implements CancellationRemoteDatasource {}

const _path = '/config/cancellation-fee';

Response<dynamic> _ok(dynamic data) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: _path),
);

/// Réponse de `GET /config/cancellation-fee` frais allumés (contrat du back).
const _activeJson = {
  'active': true,
  'effectiveFrom': '2026-12-15T00:00:00Z',
  'capEur': 30,
  'tiers': [
    {'minDaysBefore': 5, 'rate': 0},
    {'minDaysBefore': 3, 'rate': 0.1},
    {'minDaysBefore': 1, 'rate': 0.2},
    {'minDaysBefore': 0, 'rate': 0.3},
  ],
};

void main() {
  group('CancellationFeeConfigModel.fromJson', () {
    test('frais allumés : date d\'effet, plafond et paliers', () {
      final m = CancellationFeeConfigModel.fromJson(_activeJson);
      expect(m.active, isTrue);
      expect(m.effectiveFrom, DateTime.utc(2026, 12, 15));
      expect(m.capEur, 30);
      expect(m.tiers, const [
        CancellationFeeTier(minDaysBefore: 5, rate: 0),
        CancellationFeeTier(minDaysBefore: 3, rate: 0.1),
        CancellationFeeTier(minDaysBefore: 1, rate: 0.2),
        CancellationFeeTier(minDaysBefore: 0, rate: 0.3),
      ]);
    });

    test('frais éteints : date d\'effet nulle', () {
      final m = CancellationFeeConfigModel.fromJson(const {
        'active': false,
        'effectiveFrom': null,
        'capEur': 30,
        'tiers': [],
      });
      expect(m.active, isFalse);
      expect(m.effectiveFrom, isNull);
      expect(m.capEur, 30);
      expect(m.tiers, isEmpty);
    });

    test('éteint même avec une date : la date n\'est pas gardée', () {
      final m = CancellationFeeConfigModel.fromJson(const {
        'active': false,
        'effectiveFrom': '2026-12-15T00:00:00Z',
      });
      expect(m.active, isFalse);
      expect(m.effectiveFrom, isNull);
    });

    test('allumé sans date d\'effet lisible : traité comme éteint', () {
      for (final from in [null, '', 'demain', 42]) {
        final m = CancellationFeeConfigModel.fromJson({
          'active': true,
          'effectiveFrom': from,
        });
        expect(m.active, isFalse, reason: 'effectiveFrom = $from');
        expect(m.effectiveFrom, isNull);
      }
    });

    test('champs absents : éteint, sans plafond ni palier', () {
      final m = CancellationFeeConfigModel.fromJson(const {});
      expect(m, CancellationFeeConfigModel.inactive);
      expect(m.capEur, isNull);
      expect(m.tiers, isEmpty);
    });

    test('`active` qui n\'est pas le booléen vrai : éteint', () {
      for (final active in ['true', 1, null, 'yes']) {
        final m = CancellationFeeConfigModel.fromJson({
          'active': active,
          'effectiveFrom': '2026-12-15T00:00:00Z',
        });
        expect(m.active, isFalse, reason: 'active = $active');
      }
    });

    test('plafond et taux en texte décimal, paliers illisibles ignorés', () {
      final m = CancellationFeeConfigModel.fromJson(const {
        'active': true,
        'effectiveFrom': '2026-12-15T00:00:00Z',
        'capEur': '30.00',
        'tiers': [
          {'minDaysBefore': 3, 'rate': '0.10'},
          {'minDaysBefore': 'trois', 'rate': 0.2},
          {'minDaysBefore': 1},
          'palier',
          null,
        ],
      });
      expect(m.active, isTrue);
      expect(m.capEur, 30);
      expect(m.tiers, const [CancellationFeeTier(minDaysBefore: 3, rate: 0.1)]);
    });

    test('plafond illisible et paliers qui ne sont pas une liste', () {
      final m = CancellationFeeConfigModel.fromJson(const {
        'active': true,
        'effectiveFrom': '2026-12-15T00:00:00Z',
        'capEur': 'trente',
        'tiers': {'minDaysBefore': 0},
      });
      expect(m.active, isTrue);
      expect(m.capEur, isNull);
      expect(m.tiers, isEmpty);
    });

    test('égalité de valeur', () {
      expect(
        CancellationFeeConfigModel.fromJson(_activeJson),
        CancellationFeeConfigModel.fromJson(_activeJson),
      );
      expect(
        CancellationFeeConfigModel.fromJson(_activeJson),
        isNot(CancellationFeeConfigModel.inactive),
      );
    });
  });

  group('CancellationRemoteDatasource.getFeeConfig', () {
    late _MockApiClient client;
    late _MockDio dio;
    late CancellationRemoteDatasource datasource;

    setUp(() {
      client = _MockApiClient();
      dio = _MockDio();
      when(() => client.dio).thenReturn(dio);
      datasource = CancellationRemoteDatasource(client);
    });

    test('GET /config/cancellation-fee → modèle', () async {
      when(() => dio.get(_path)).thenAnswer((_) async => _ok(_activeJson));

      final m = await datasource.getFeeConfig();

      expect(m.active, isTrue);
      expect(m.effectiveFrom, DateTime.utc(2026, 12, 15));
      verify(() => dio.get(_path)).called(1);
    });

    test('frais éteints → modèle éteint', () async {
      when(
        () => dio.get(_path),
      ).thenAnswer((_) async => _ok({'active': false, 'effectiveFrom': null}));
      expect(
        await datasource.getFeeConfig(),
        CancellationFeeConfigModel.inactive,
      );
    });

    test('corps qui n\'est pas un objet → FormatException', () async {
      when(() => dio.get(_path)).thenAnswer((_) async => _ok('<html>'));
      expect(datasource.getFeeConfig, throwsA(isA<FormatException>()));
    });

    test('404 (back antérieur) : l\'erreur remonte telle quelle', () async {
      when(() => dio.get(_path)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _path),
          response: Response(
            statusCode: 404,
            requestOptions: RequestOptions(path: _path),
          ),
          type: DioExceptionType.badResponse,
          error: const NotFoundException(),
        ),
      );
      expect(
        datasource.getFeeConfig,
        throwsA(
          isA<DioException>().having(
            (e) => unwrapDioError(e),
            'erreur',
            isA<NotFoundException>(),
          ),
        ),
      );
    });
  });

  test('CancellationRepository.getFeeConfig délègue au datasource', () async {
    final datasource = _MockDatasource();
    when(
      datasource.getFeeConfig,
    ).thenAnswer((_) async => CancellationFeeConfigModel.inactive);

    final m = await CancellationRepository(datasource).getFeeConfig();

    expect(m, CancellationFeeConfigModel.inactive);
    verify(datasource.getFeeConfig).called(1);
  });
}
