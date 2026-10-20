import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/data/datasources/mobile_money_account_remote_datasource.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

const _path = '/payments/mobile-money/account';
const _providersPath = '/payments/mobile-money/providers';

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

  final catalogJson = {
    'country': 'CI',
    'currency': 'XOF',
    'msisdnMasked': '+225 •••• 36',
    'detected': 'ORANGE_CIV',
    'providers': [
      {'code': 'ORANGE_CIV', 'label': 'Orange Money', 'detected': true},
      {'code': 'WAVE_CIV', 'label': 'Wave', 'detected': false},
    ],
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

  group('providers', () {
    test('POST /payments/mobile-money/providers avec le numéro', () async {
      when(
        () => mockDio.post(
          _providersPath,
          data: {'phoneNumber': '+225 07 08 09 10 36'},
        ),
      ).thenAnswer((_) async => _ok(catalogJson, _providersPath));

      final result = await datasource.providers(
        phoneNumber: '+225 07 08 09 10 36',
      );

      expect(result.detected, 'ORANGE_CIV');
      expect(result.providers.length, 2);
    });

    test('sans numéro : POST sans corps', () async {
      when(
        () => mockDio.post(_providersPath),
      ).thenAnswer((_) async => _ok(catalogJson, _providersPath));

      final result = await datasource.providers();

      expect(result.country, 'CI');
      verify(() => mockDio.post(_providersPath)).called(1);
    });
  });

  group('activate avec réseaux', () {
    test('envoie phoneNumber et providers', () async {
      when(
        () => mockDio.post(
          _path,
          data: {
            'phoneNumber': '+225 07 08 09 10 36',
            'providers': ['ORANGE_CIV', 'WAVE_CIV'],
          },
        ),
      ).thenAnswer((_) async => _ok(accountJson, _path));

      final result = await datasource.activate(
        phoneNumber: '+225 07 08 09 10 36',
        providers: ['ORANGE_CIV', 'WAVE_CIV'],
      );

      expect(result.status, MobileMoneyAccountStatus.active);
    });
  });

  group('updateProviders', () {
    test('PUT /payments/mobile-money/account/providers', () async {
      when(
        () => mockDio.put(
          '$_path/providers',
          data: {
            'providers': ['WAVE_CIV'],
          },
        ),
      ).thenAnswer((_) async => _ok(accountJson, '$_path/providers'));

      final result = await datasource.updateProviders(['WAVE_CIV']);

      expect(result.status, MobileMoneyAccountStatus.active);
      verify(
        () => mockDio.put(
          '$_path/providers',
          data: {
            'providers': ['WAVE_CIV'],
          },
        ),
      ).called(1);
    });
  });

  group('comptes de versement (nouveau contrat)', () {
    const accountsPath = '/payments/mobile-money/accounts';
    final payoutJson = {
      'id': 'acc-1',
      'provider': 'ORANGE_CIV',
      'providerLabel': 'Orange Money',
      'brand': 'ORANGE',
      'country': 'CI',
      'currency': 'XOF',
      'msisdnMasked': '+225 •••• 36',
      'pendingPayouts': 0,
    };

    test('accounts : GET /accounts et parse la liste', () async {
      when(() => mockDio.get(accountsPath)).thenAnswer(
        (_) async => _ok({
          'accounts': [payoutJson],
          'suggestedProviders': [
            {'code': 'WAVE_CIV', 'label': 'Wave'},
          ],
        }, accountsPath),
      );

      final result = await datasource.accounts();

      expect(result.accounts.single.id, 'acc-1');
      expect(result.suggested.single.code, 'WAVE_CIV');
      verify(() => mockDio.get(accountsPath)).called(1);
    });

    test('addAccount : POST /accounts avec numéro et réseau', () async {
      when(
        () => mockDio.post(
          accountsPath,
          data: {'phoneNumber': '+2250708091036', 'provider': 'ORANGE_CIV'},
        ),
      ).thenAnswer((_) async => _ok(payoutJson, accountsPath));

      final result = await datasource.addAccount(
        phoneNumber: '+2250708091036',
        provider: 'ORANGE_CIV',
      );

      expect(result.provider, 'ORANGE_CIV');
    });

    test('changeNumber : PUT /accounts/{id}/number', () async {
      const path = '$accountsPath/acc-1/number';
      when(
        () => mockDio.put(path, data: {'phoneNumber': '+2250708091037'}),
      ).thenAnswer((_) async => _ok(payoutJson, path));

      final result = await datasource.changeNumber(
        id: 'acc-1',
        phoneNumber: '+2250708091037',
      );

      expect(result.id, 'acc-1');
    });

    test('removeAccount : DELETE /accounts/{id} sans corps', () async {
      const path = '$accountsPath/acc-1';
      when(() => mockDio.delete(path)).thenAnswer((_) async => _ok(null, path));

      await datasource.removeAccount('acc-1');

      verify(() => mockDio.delete(path)).called(1);
      verifyNever(() => mockDio.delete(path, data: any(named: 'data')));
    });

    test('payoutCountries : GET countries?operation=PAYOUT', () async {
      const path = '/payments/mobile-money/countries';
      when(
        () => mockDio.get(path, queryParameters: {'operation': 'PAYOUT'}),
      ).thenAnswer(
        (_) async => _ok({
          'available': [],
          'upcoming': ['ML'],
        }, path),
      );

      final result = await datasource.payoutCountries();

      expect(result.upcoming, ['ML']);
    });

    test('propage la DioException', () async {
      when(() => mockDio.get(accountsPath)).thenThrow(
        DioException(requestOptions: RequestOptions(path: accountsPath)),
      );

      expect(datasource.accounts(), throwsA(isA<DioException>()));
    });
  });
}
