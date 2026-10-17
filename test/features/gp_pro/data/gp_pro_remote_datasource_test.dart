import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/gp_pro/data/datasources/gp_pro_remote_datasource.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path, [int code = 200]) => Response(
  data: data,
  statusCode: code,
  requestOptions: RequestOptions(path: path),
);

void main() {
  late MockApiClient client;
  late MockDio dio;
  late GpProRemoteDatasource datasource;

  setUpAll(() => registerFallbackValue(FormData()));

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    datasource = GpProRemoteDatasource(client);
  });

  test('fetchStatus lit GET /gp-pro/me', () async {
    when(
      () => dio.get('/gp-pro/me'),
    ).thenAnswer((_) async => _ok({'state': 'PENDING'}, '/gp-pro/me'));

    final status = await datasource.fetchStatus();

    expect(status.state, GpProState.pending);
  });

  test('apply envoie fréquence, nom, documents et source', () async {
    when(
      () => dio.post('/gp-pro/applications', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => _ok({'state': 'PENDING'}, '/gp-pro/applications', 201),
    );

    final status = await datasource.apply(
      frequency: GpProFrequency.weekly,
      commercialName: 'Awa Express',
      documentIds: const ['d1', 'd2'],
      source: GpProSource.profile,
    );

    expect(status.state, GpProState.pending);
    final body =
        verify(
              () => dio.post(
                '/gp-pro/applications',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body, {
      'travelFrequency': 'WEEKLY',
      'commercialName': 'Awa Express',
      'documentIds': ['d1', 'd2'],
      'source': 'PROFILE',
    });
  });

  test('apply omet le nom vide et les documents vides', () async {
    when(
      () => dio.post('/gp-pro/applications', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => _ok({'state': 'AWAITING_KYC'}, '/gp-pro/applications', 201),
    );

    await datasource.apply(
      frequency: GpProFrequency.monthly,
      commercialName: '   ',
      source: GpProSource.signup,
    );

    final body =
        verify(
              () => dio.post(
                '/gp-pro/applications',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body, {'travelFrequency': 'MONTHLY', 'source': 'SIGNUP'});
  });

  test('uploadDocument envoie un FormData file + type', () async {
    final dir = Directory.systemTemp.createTempSync('gp_pro_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/preuve.jpg')..writeAsBytesSync([1, 2, 3]);
    when(
      () => dio.post('/gp-pro/documents', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => _ok(
        {'documentId': 'd9', 'type': 'TRAVEL_PROOF'},
        '/gp-pro/documents',
        201,
      ),
    );

    final doc = await datasource.uploadDocument(
      filePath: file.path,
      type: GpProDocType.travelProof,
    );

    expect(doc, const GpProDocument(id: 'd9', type: GpProDocType.travelProof));
    final form =
        verify(
              () => dio.post(
                '/gp-pro/documents',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as FormData;
    final fields = {for (final f in form.fields) f.key: f.value};
    expect(fields['type'], 'TRAVEL_PROOF');
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'preuve.jpg');
  });

  test('attachDocuments poste les ids sur la demande courante', () async {
    when(
      () => dio.post(
        '/gp-pro/applications/current/documents',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => _ok({
        'state': 'PENDING',
        'documentCount': 2,
      }, '/gp-pro/applications/current/documents'),
    );

    final status = await datasource.attachDocuments(const ['d1', 'd2']);

    expect(status.documentCount, 2);
    verify(
      () => dio.post(
        '/gp-pro/applications/current/documents',
        data: {
          'documentIds': ['d1', 'd2'],
        },
      ),
    ).called(1);
  });

  test('removeDocument supprime /gp-pro/documents/{id}', () async {
    when(
      () => dio.delete('/gp-pro/documents/d1'),
    ).thenAnswer((_) async => _ok(null, '/gp-pro/documents/d1', 204));

    await datasource.removeDocument('d1');

    verify(() => dio.delete('/gp-pro/documents/d1')).called(1);
  });

  test('cancel supprime /gp-pro/applications/current', () async {
    when(
      () => dio.delete('/gp-pro/applications/current'),
    ).thenAnswer((_) async => _ok(null, '/gp-pro/applications/current', 204));

    await datasource.cancel();

    verify(() => dio.delete('/gp-pro/applications/current')).called(1);
  });
}
