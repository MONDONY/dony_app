import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/data/datasources/mobile_money_account_remote_datasource.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

const _path = '/payments/mobile-money/account';

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late MobileMoneyAccountRemoteDatasource datasource;

  final accountJson = {
    'status': 'ACTIVE',
    'msisdnMasked': '+221 •••• 67',
    'providerLabel': 'Orange Money',
    'country': 'SN',
    'currency': 'XOF',
  };

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    datasource = MobileMoneyAccountRemoteDatasource(mockClient);
  });

  group('get', () {
    test(
      'appelle GET /payments/mobile-money/account et parse le compte',
      () async {
        when(
          () => mockDio.get(_path),
        ).thenAnswer((_) async => _ok(accountJson, _path));

        final result = await datasource.get();

        expect(result.status, MobileMoneyAccountStatus.active);
        expect(result.msisdnMasked, '+221 •••• 67');
        verify(() => mockDio.get(_path)).called(1);
      },
    );

    test('propage la DioException sur erreur réseau', () async {
      when(() => mockDio.get(_path)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _path),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(datasource.get(), throwsA(isA<DioException>()));
    });
  });

  group('activate', () {
    test('appelle POST sans corps et renvoie le compte activé', () async {
      final activated = {...accountJson, 'status': 'ACTIVE'};
      when(
        () => mockDio.post(_path),
      ).thenAnswer((_) async => _ok(activated, _path));

      final result = await datasource.activate();

      expect(result.status, MobileMoneyAccountStatus.active);
      verify(() => mockDio.post(_path)).called(1);
    });

    test('propage la DioException sur erreur serveur', () async {
      when(() => mockDio.post(_path)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _path),
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: _path),
          ),
        ),
      );

      expect(datasource.activate(), throwsA(isA<DioException>()));
    });

    // Tâche numéro de versement : le compte Firebase peut n'avoir aucun
    // téléphone (SMS Twilio pas encore configuré) — l'app fournit alors le
    // numéro saisi par le voyageur dans le corps de la requête.
    test('avec un numéro : POST avec le corps {phoneNumber} et renvoie le '
        'compte activé', () async {
      final activated = {...accountJson, 'status': 'ACTIVE'};
      when(
        () => mockDio.post(_path, data: {'phoneNumber': '+221773456789'}),
      ).thenAnswer((_) async => _ok(activated, _path));

      final result = await datasource.activate(phoneNumber: '+221773456789');

      expect(result.status, MobileMoneyAccountStatus.active);
      verify(
        () => mockDio.post(_path, data: {'phoneNumber': '+221773456789'}),
      ).called(1);
    });

    test(
      'phoneNumber nul : aucun corps envoyé (comportement historique)',
      () async {
        when(
          () => mockDio.post(_path),
        ).thenAnswer((_) async => _ok(accountJson, _path));

        await datasource.activate();

        verify(() => mockDio.post(_path)).called(1);
        verifyNever(() => mockDio.post(_path, data: any(named: 'data')));
      },
    );
  });

  group('disable', () {
    test('appelle DELETE et renvoie le compte désactivé', () async {
      final disabled = {...accountJson, 'status': 'DISABLED'};
      when(
        () => mockDio.delete(_path),
      ).thenAnswer((_) async => _ok(disabled, _path));

      final result = await datasource.disable();

      expect(result.status, MobileMoneyAccountStatus.disabled);
      verify(() => mockDio.delete(_path)).called(1);
    });

    test('propage la DioException sur erreur réseau', () async {
      when(() => mockDio.delete(_path)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _path),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(datasource.disable(), throwsA(isA<DioException>()));
    });
  });
}
