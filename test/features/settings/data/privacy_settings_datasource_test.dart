import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/datasources/privacy_settings_datasource.dart';
import 'package:dony/features/settings/data/models/privacy_settings_model.dart';
import 'package:dony/features/settings/data/repositories/privacy_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class MockPrivacySettingsDatasource extends Mock
    implements PrivacySettingsDatasource {}

Response<dynamic> _response(Map<String, dynamic>? data) => Response(
  data: data,
  requestOptions: RequestOptions(path: ''),
  statusCode: 200,
);

void main() {
  late MockApiClient mockApi;
  late MockDio mockDio;
  late PrivacySettingsDatasource datasource;

  setUpAll(() {
    registerFallbackValue(
      const PrivacySettingsModel(contactKycOnly: true, hidePhoneNumber: false),
    );
  });

  setUp(() {
    mockApi = MockApiClient();
    mockDio = MockDio();
    when(() => mockApi.dio).thenReturn(mockDio);
    datasource = PrivacySettingsDatasource(mockApi);
  });

  group('PrivacySettingsDatasource', () {
    test(
      'fetch appelle GET /auth/me/privacy-settings et parse les 2 drapeaux',
      () async {
        when(() => mockDio.get('/auth/me/privacy-settings')).thenAnswer(
          (_) async =>
              _response({'contactKycOnly': false, 'hidePhoneNumber': true}),
        );

        final settings = await datasource.fetch();

        expect(settings.contactKycOnly, isFalse);
        expect(settings.hidePhoneNumber, isTrue);
      },
    );

    test('update envoie les deux préférences dans le PUT', () async {
      when(
        () =>
            mockDio.put('/auth/me/privacy-settings', data: any(named: 'data')),
      ).thenAnswer((_) async => _response(null));

      await datasource.update(
        const PrivacySettingsModel(contactKycOnly: true, hidePhoneNumber: true),
      );

      verify(
        () => mockDio.put(
          '/auth/me/privacy-settings',
          data: {'contactKycOnly': true, 'hidePhoneNumber': true},
        ),
      ).called(1);
    });
  });

  group('PrivacySettingsModel', () {
    /// Un backend antérieur au champ ne renvoie pas `hidePhoneNumber` : le défaut
    /// doit être « numéro visible », comme la colonne côté serveur.
    test('un JSON sans hidePhoneNumber vaut false', () {
      final settings = PrivacySettingsModel.fromJson({'contactKycOnly': false});

      expect(settings.hidePhoneNumber, isFalse);
      expect(settings.contactKycOnly, isFalse);
    });

    test('un JSON vide retombe sur les défauts du backend', () {
      final settings = PrivacySettingsModel.fromJson({});

      expect(settings.contactKycOnly, isTrue);
      expect(settings.hidePhoneNumber, isFalse);
    });

    test('equality et hashCode couvrent les deux champs', () {
      const a = PrivacySettingsModel(
        contactKycOnly: true,
        hidePhoneNumber: false,
      );
      const b = PrivacySettingsModel(
        contactKycOnly: true,
        hidePhoneNumber: false,
      );
      const c = PrivacySettingsModel(
        contactKycOnly: true,
        hidePhoneNumber: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('PrivacySettingsRepository', () {
    late MockPrivacySettingsDatasource mockDatasource;
    late PrivacySettingsRepository repository;

    setUp(() {
      mockDatasource = MockPrivacySettingsDatasource();
      repository = PrivacySettingsRepository(mockDatasource);
    });

    test('fetch délègue au datasource', () async {
      when(() => mockDatasource.fetch()).thenAnswer(
        (_) async => const PrivacySettingsModel(
          contactKycOnly: false,
          hidePhoneNumber: true,
        ),
      );

      final settings = await repository.fetch();

      expect(settings.hidePhoneNumber, isTrue);
      verify(() => mockDatasource.fetch()).called(1);
    });

    test('update délègue au datasource', () async {
      when(() => mockDatasource.update(any())).thenAnswer((_) async {});
      const settings = PrivacySettingsModel(
        contactKycOnly: true,
        hidePhoneNumber: true,
      );

      await repository.update(settings);

      verify(() => mockDatasource.update(settings)).called(1);
    });
  });
}
