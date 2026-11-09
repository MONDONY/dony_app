import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/app_update/data/datasources/remote_config_interval_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

void main() {
  group('SharedPrefsRemoteConfigIntervalStore', () {
    test('lit null puis la valeur écrite', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsRemoteConfigIntervalStore();
      expect(await store.read(), isNull);
      await store.write(45);
      expect(await store.read(), 45);
    });

    test('ignore une valeur mémorisée hors bornes', () async {
      SharedPreferences.setMockInitialValues({
        'remote_config_refresh_minutes': 2,
      });
      expect(await SharedPrefsRemoteConfigIntervalStore().read(), isNull);
    });
  });

  group('ApiRemoteConfigIntervalRemote', () {
    late _MockDio dio;
    late ApiRemoteConfigIntervalRemote remote;

    setUp(() {
      dio = _MockDio();
      final client = _MockApiClient();
      when(() => client.dio).thenReturn(dio);
      remote = ApiRemoteConfigIntervalRemote(client);
    });

    Response<dynamic> reply(dynamic data) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/config/remote-config-refresh'),
      data: data,
    );

    test('lit le champ minutes', () async {
      when(
        () => dio.get<dynamic>('/config/remote-config-refresh'),
      ).thenAnswer((_) async => reply({'minutes': 60}));
      expect(await remote.fetchMinutes(), 60);
    });

    test('renvoie null si le corps n\'est pas un objet', () async {
      when(
        () => dio.get<dynamic>('/config/remote-config-refresh'),
      ).thenAnswer((_) async => reply('oops'));
      expect(await remote.fetchMinutes(), isNull);
    });
  });

  test('bornes de validation', () {
    expect(isValidRemoteConfigRefreshMinutes(5), isTrue);
    expect(isValidRemoteConfigRefreshMinutes(1440), isTrue);
    expect(isValidRemoteConfigRefreshMinutes(4), isFalse);
    expect(isValidRemoteConfigRefreshMinutes(1441), isFalse);
    expect(isValidRemoteConfigRefreshMinutes(60.0), isFalse);
  });
}
