import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/maintenance/data/datasources/maintenance_live_datasource.dart';
import 'package:dony/features/maintenance/data/datasources/maintenance_remote_datasource.dart';
import 'package:dony/features/maintenance/data/models/maintenance_status.dart';
import 'package:dony/features/maintenance/data/repositories/maintenance_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final String body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('MaintenanceStatus', () {
    test('fromJson complet', () {
      final s = MaintenanceStatus.fromJson(const {
        'enabled': true,
        'message': 'Pause',
        'estimatedEndAt': '2026-10-16T14:30:00Z',
        'exempt': false,
      });
      expect(s.enabled, isTrue);
      expect(s.message, 'Pause');
      expect(s.estimatedEndAt, DateTime.utc(2026, 10, 16, 14, 30));
      expect(s.blocksApp, isTrue);
    });

    test('fromJson minimal et exemption', () {
      expect(MaintenanceStatus.fromJson(const {}).blocksApp, isFalse);
      expect(
        MaintenanceStatus.fromJson(const {
          'enabled': true,
          'exempt': true,
        }).blocksApp,
        isFalse,
      );
      expect(
        MaintenanceStatus.fromJson(const {
          'enabled': true,
          'estimatedEndAt': 12,
        }).estimatedEndAt,
        isNull,
      );
      expect(
        const MaintenanceStatus(enabled: true),
        const MaintenanceStatus(enabled: true),
      );
    });
  });

  test('remote : GET /config/maintenance sans retry empilé', () async {
    final adapter = _JsonAdapter(
      '{"enabled":true,"message":null,"exempt":true}',
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    final client = _MockApiClient();
    when(() => client.dio).thenReturn(dio);

    final status = await MaintenanceRemoteDatasource(client).fetchStatus();

    expect(adapter.last?.path, '/config/maintenance');
    expect(adapter.last?.extra['skipTransientRetry'], isTrue);
    expect(status.enabled, isTrue);
    expect(status.exempt, isTrue);
  });

  test('live : suit le document config/maintenance', () async {
    final firestore = FakeFirebaseFirestore();
    final live = MaintenanceLiveDatasource(firestore);
    final values = <bool>[];
    final sub = live.watchEnabled().listen(values.add);
    await pumpEventQueue();

    await firestore.collection('config').doc('maintenance').set({
      'enabled': true,
    });
    await pumpEventQueue();
    await firestore.collection('config').doc('maintenance').set({
      'enabled': false,
    });
    await pumpEventQueue();
    await sub.cancel();

    expect(values, [false, true, false]);
  });

  test('repository délègue aux deux sources', () async {
    final adapter = _JsonAdapter('{"enabled":false}');
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    final client = _MockApiClient();
    when(() => client.dio).thenReturn(dio);
    final firestore = FakeFirebaseFirestore();
    final repo = MaintenanceRepository(
      MaintenanceRemoteDatasource(client),
      MaintenanceLiveDatasource(firestore),
    );

    expect((await repo.fetchStatus()).enabled, isFalse);
    expect(await repo.watchEnabled().first, isFalse);
  });
}
