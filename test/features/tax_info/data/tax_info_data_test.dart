import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/tax_info/data/datasources/tax_info_remote_datasource.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class MockDatasource extends Mock implements TaxInfoRemoteDatasource {}

const _path = '/travelers/me/tax-info';

Response<dynamic> _ok(dynamic data) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: _path),
);

DioException _http(int status, [Object? body]) => DioException(
  requestOptions: RequestOptions(path: _path),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: _path),
    statusCode: status,
    data: body,
  ),
);

void main() {
  group('TaxInfo.fromJson', () {
    test('lit toute la réponse', () {
      final info = TaxInfo.fromJson({
        'provided': true,
        'maskedTaxIdentificationNumber': '****1234',
        'taxCountry': 'FR',
        'vatNumberProvided': true,
        'maskedVatNumber': '****789',
        'providedAt': '2026-11-10T08:30:00Z',
        'residenceCountry': 'FR',
        'dac7Status': 'DECLARABLE',
        'solicitation': 'DEJA_FOURNI',
      });
      expect(info.provided, isTrue);
      expect(info.maskedTaxIdentificationNumber, '****1234');
      expect(info.taxCountry, 'FR');
      expect(info.vatNumberProvided, isTrue);
      expect(info.maskedVatNumber, '****789');
      expect(info.providedAt, DateTime.utc(2026, 11, 10, 8, 30));
      expect(info.residenceCountry, 'FR');
      expect(info.dac7Status, 'DECLARABLE');
      expect(info.solicitation, TaxInfoSolicitation.dejaFourni);
    });

    test('champs nuls ou absents : valeurs sûres', () {
      final info = TaxInfo.fromJson({
        'provided': false,
        'maskedTaxIdentificationNumber': '  ',
        'solicitation': 'SOLLICITER',
      });
      expect(info.provided, isFalse);
      expect(info.maskedTaxIdentificationNumber, isNull);
      expect(info.taxCountry, isNull);
      expect(info.vatNumberProvided, isFalse);
      expect(info.providedAt, isNull);
      expect(info.solicitation, TaxInfoSolicitation.solliciter);
    });

    test('solicitation absente ou inconnue : on ne demande rien', () {
      expect(
        TaxInfo.fromJson({'provided': false}).solicitation,
        TaxInfoSolicitation.nePasSolliciter,
      );
      expect(
        TaxInfo.fromJson({'solicitation': 'AUTRE'}).solicitation,
        TaxInfoSolicitation.nePasSolliciter,
      );
    });
  });

  group('TaxInfoRemoteDatasource', () {
    late MockApiClient client;
    late MockDio dio;
    late TaxInfoRemoteDatasource datasource;

    setUp(() {
      client = MockApiClient();
      dio = MockDio();
      when(() => client.dio).thenReturn(dio);
      datasource = TaxInfoRemoteDatasource(client);
    });

    test('fetch lit GET /travelers/me/tax-info', () async {
      when(() => dio.get(_path)).thenAnswer(
        (_) async => _ok({'provided': false, 'solicitation': 'SOLLICITER'}),
      );
      final info = await datasource.fetch();
      expect(info.solicitation, TaxInfoSolicitation.solliciter);
    });

    test('save envoie numéro, pays et TVA rognés', () async {
      when(() => dio.put(_path, data: any(named: 'data'))).thenAnswer(
        (_) async => _ok({
          'provided': true,
          'maskedTaxIdentificationNumber': '****4567',
          'solicitation': 'DEJA_FOURNI',
        }),
      );
      final info = await datasource.save(
        taxIdentificationNumber: ' 1234567 ',
        taxCountry: 'FR',
        vatNumber: ' FR123 ',
      );
      expect(info.provided, isTrue);
      final body =
          verify(
                () => dio.put(_path, data: captureAny(named: 'data')),
              ).captured.single
              as Map<String, dynamic>;
      expect(body, {
        'taxIdentificationNumber': '1234567',
        'taxCountry': 'FR',
        'vatNumber': 'FR123',
      });
    });

    test('save n\'envoie pas de TVA vide', () async {
      when(
        () => dio.put(_path, data: any(named: 'data')),
      ).thenAnswer((_) async => _ok({'provided': true}));
      await datasource.save(
        taxIdentificationNumber: '1234567',
        taxCountry: 'SN',
        vatNumber: '   ',
      );
      final body =
          verify(
                () => dio.put(_path, data: captureAny(named: 'data')),
              ).captured.single
              as Map<String, dynamic>;
      expect(body.containsKey('vatNumber'), isFalse);
    });
  });

  group('TaxInfoRepository', () {
    late MockDatasource ds;
    late TaxInfoRepository repo;

    setUp(() {
      ds = MockDatasource();
      repo = TaxInfoRepository(ds);
    });

    test('transmet les succès', () async {
      const info = TaxInfo(
        provided: false,
        solicitation: TaxInfoSolicitation.solliciter,
      );
      when(() => ds.fetch()).thenAnswer((_) async => info);
      when(
        () => ds.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      ).thenAnswer((_) async => info);
      expect(await repo.fetch(), info);
      expect(
        await repo.save(taxIdentificationNumber: '1234', taxCountry: 'FR'),
        info,
      );
    });

    for (final status in [404, 403, 401]) {
      test('$status = fonction absente', () async {
        when(() => ds.fetch()).thenThrow(
          _http(status, {'type': 'https://yadony.com/errors/dac7-disabled'}),
        );
        await expectLater(
          repo.fetch(),
          throwsA(
            isA<TaxInfoUnavailableException>().having(
              (e) => e.status,
              'status',
              status,
            ),
          ),
        );
      });
    }

    test('404 sans corps (ancien back) = fonction absente', () async {
      when(() => ds.fetch()).thenThrow(_http(404));
      await expectLater(
        repo.fetch(),
        throwsA(isA<TaxInfoUnavailableException>()),
      );
    });

    test('422 : dernier segment du type RFC 7807', () async {
      when(
        () => ds.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      ).thenThrow(
        _http(422, {'type': 'https://yadony.com/errors/tax-info-invalid'}),
      );
      await expectLater(
        repo.save(taxIdentificationNumber: 'x', taxCountry: 'FR'),
        throwsA(
          isA<TaxInfoException>()
              .having((e) => e.code, 'code', 'tax-info-invalid')
              .having((e) => e.status, 'status', 422),
        ),
      );
    });

    test('code d\'extension quand le type manque', () async {
      when(() => ds.fetch()).thenThrow(_http(500, {'code': 'boom'}));
      await expectLater(
        repo.fetch(),
        throwsA(isA<TaxInfoException>().having((e) => e.code, 'code', 'boom')),
      );
    });

    test('corps illisible : unknown', () async {
      when(() => ds.fetch()).thenThrow(_http(500, 'oops'));
      await expectLater(
        repo.fetch(),
        throwsA(
          isA<TaxInfoException>().having((e) => e.code, 'code', 'unknown'),
        ),
      );
    });

    test('sans réponse : network', () async {
      when(() => ds.fetch()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _path),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        repo.fetch(),
        throwsA(
          isA<TaxInfoException>()
              .having((e) => e.code, 'code', 'network')
              .having((e) => e.toString(), 'toString', contains('network')),
        ),
      );
    });
  });
}
