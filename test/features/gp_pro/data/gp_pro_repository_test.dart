import 'package:dio/dio.dart';
import 'package:dony/features/gp_pro/data/datasources/gp_pro_remote_datasource.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDatasource extends Mock implements GpProRemoteDatasource {}

DioException _http(int status, [Object? body]) => DioException(
  requestOptions: RequestOptions(path: '/gp-pro'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/gp-pro'),
    statusCode: status,
    data: body,
  ),
);

void main() {
  late MockDatasource ds;
  late GpProRepository repo;

  setUpAll(() {
    registerFallbackValue(GpProFrequency.weekly);
    registerFallbackValue(GpProSource.signup);
    registerFallbackValue(GpProDocType.other);
  });

  setUp(() {
    ds = MockDatasource();
    repo = GpProRepository(ds);
  });

  test('transmet les succès', () async {
    const status = GpProStatus(state: GpProState.active);
    when(() => ds.fetchStatus()).thenAnswer((_) async => status);
    expect(await repo.fetchStatus(), status);
  });

  test('apply, upload, attach, remove et cancel délèguent', () async {
    const status = GpProStatus(state: GpProState.pending);
    const doc = GpProDocument(id: 'd1', type: GpProDocType.other);
    when(
      () => ds.apply(
        frequency: any(named: 'frequency'),
        commercialName: any(named: 'commercialName'),
        documentIds: any(named: 'documentIds'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async => status);
    when(
      () => ds.uploadDocument(
        filePath: any(named: 'filePath'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => doc);
    when(() => ds.attachDocuments(any())).thenAnswer((_) async => status);
    when(() => ds.removeDocument(any())).thenAnswer((_) async {});
    when(() => ds.cancel()).thenAnswer((_) async {});

    expect(
      await repo.apply(
        frequency: GpProFrequency.weekly,
        source: GpProSource.signup,
      ),
      status,
    );
    expect(
      await repo.uploadDocument(filePath: 'a.jpg', type: GpProDocType.other),
      doc,
    );
    expect(await repo.attachDocuments(const ['d1']), status);
    await repo.removeDocument('d1');
    await repo.cancel();
    verify(() => ds.removeDocument('d1')).called(1);
    verify(() => ds.cancel()).called(1);
  });

  test('404 sur fetchStatus lève GpProUnavailableException', () async {
    when(() => ds.fetchStatus()).thenThrow(_http(404));
    await expectLater(
      repo.fetchStatus(),
      throwsA(isA<GpProUnavailableException>()),
    );
  });

  test('404 sans type gp-pro sur apply lève GpProUnavailableException', () {
    when(
      () => ds.apply(
        frequency: any(named: 'frequency'),
        commercialName: any(named: 'commercialName'),
        documentIds: any(named: 'documentIds'),
        source: any(named: 'source'),
      ),
    ).thenThrow(_http(404, {'type': 'https://x/errors/not-found'}));
    expect(
      repo.apply(frequency: GpProFrequency.weekly, source: GpProSource.signup),
      throwsA(isA<GpProUnavailableException>()),
    );
  });

  test('404 gp-pro-application-not-found reste une GpProException', () async {
    when(() => ds.cancel()).thenThrow(
      _http(404, {'type': 'https://api/errors/gp-pro-application-not-found'}),
    );
    try {
      await repo.cancel();
      fail('doit lever');
    } on GpProException catch (e) {
      expect(e, isNot(isA<GpProUnavailableException>()));
      expect(e.code, 'gp-pro-application-not-found');
      expect(e.status, 404);
    }
  });

  test('409 expose le dernier segment du type', () async {
    when(() => ds.fetchStatus()).thenThrow(
      _http(409, {
        'type': 'https://api.yadony.com/errors/gp-pro-application-open',
      }),
    );
    try {
      await repo.fetchStatus();
      fail('doit lever');
    } on GpProException catch (e) {
      expect(e.code, 'gp-pro-application-open');
      expect(e.status, 409);
    }
  });

  test('repli sur code, puis sur unknown', () async {
    when(() => ds.removeDocument(any())).thenThrow(_http(503, {'code': 'x-y'}));
    await expectLater(
      repo.removeDocument('d'),
      throwsA(isA<GpProException>().having((e) => e.code, 'code', 'x-y')),
    );
    when(() => ds.removeDocument(any())).thenThrow(_http(500, 'oups'));
    await expectLater(
      repo.removeDocument('d'),
      throwsA(isA<GpProException>().having((e) => e.code, 'code', 'unknown')),
    );
  });

  test('timeout donne le code network', () async {
    when(() => ds.fetchStatus()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/gp-pro/me'),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    try {
      await repo.fetchStatus();
      fail('doit lever');
    } on GpProException catch (e) {
      expect(e.code, 'network');
      expect(e.status, isNull);
    }
  });
}
