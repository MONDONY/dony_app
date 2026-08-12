import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/incident_report/data/datasources/incident_report_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _created(dynamic data, String path) => Response(
      data: data,
      statusCode: 201,
      requestOptions: RequestOptions(path: path),
    );

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late IncidentReportRemoteDatasource datasource;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    datasource = IncidentReportRemoteDatasource(mockClient);
  });

  group('createReport', () {
    test('poste le payload et renvoie l\'id', () async {
      when(() => mockDio.post('/reports', data: any(named: 'data')))
          .thenAnswer((_) async => _created({'id': 'r-42'}, '/reports'));

      final id = await datasource.createReport(
        targetType: 'APP',
        reason: 'Bug de l\'application',
        description: 'Crash au paiement',
        photoKeys: const ['reports/u/1.png'],
      );

      expect(id, 'r-42');
      final captured = verify(
        () => mockDio.post('/reports', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(captured['targetType'], 'APP');
      expect(captured.containsKey('targetId'), isFalse);
      expect(captured['reason'], 'Bug de l\'application');
      expect(captured['description'], 'Crash au paiement');
      expect(captured['photoKeys'], ['reports/u/1.png']);
    });

    test('omet la description vide et inclut targetId quand fourni', () async {
      when(() => mockDio.post('/reports', data: any(named: 'data')))
          .thenAnswer((_) async => _created({'id': 'r-1'}, '/reports'));

      await datasource.createReport(
        targetType: 'BID',
        targetId: 'bid-9',
        reason: 'Colis endommagé',
        description: '',
        photoKeys: const [],
      );

      final captured = verify(
        () => mockDio.post('/reports', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(captured['targetId'], 'bid-9');
      expect(captured.containsKey('description'), isFalse);
    });
  });

  group('uploadPhoto', () {
    test('renvoie la clé S3', () async {
      when(() => mockDio.post('/reports/photos', data: any(named: 'data')))
          .thenAnswer((_) async =>
              _created({'key': 'reports/u/123_capture.jpg'}, '/reports/photos'));

      // FormData exige un fichier réel : on passe par un fichier temporaire.
      final tmp = await createTempImage();
      final key = await datasource.uploadPhoto(tmp);

      expect(key, 'reports/u/123_capture.jpg');
    });
  });
}

Future<String> createTempImage() async {
  final dir = await Directory.systemTemp.createTemp('incident_test');
  final file = File('${dir.path}/capture.jpg');
  await file.writeAsBytes([0xFF, 0xD8, 0xFF]);
  return file.path;
}
