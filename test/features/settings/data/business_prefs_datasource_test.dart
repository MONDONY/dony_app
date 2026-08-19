import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/datasources/business_prefs_remote_datasource.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApi;
  late MockDio mockDio;
  late BusinessPrefsRemoteDatasource datasource;

  setUp(() {
    mockApi = MockApiClient();
    mockDio = MockDio();
    when(() => mockApi.dio).thenReturn(mockDio);
    datasource = BusinessPrefsRemoteDatasource(mockApi);
  });

  group('BusinessPrefsRemoteDatasource', () {
    test(
      'fetchPrefs appelle GET /users/me/business-preferences et parse le DTO',
      () async {
        when(() => mockDio.get('/users/me/business-preferences')).thenAnswer(
          (_) async => Response(
            data: {
              'weightUnit': 'lbs',
              'currencyCode': 'XOF',
              'pickupRadiusKm': 20,
              'defaultPackageWeightKg': 30,
              'minBidPriceEur': 5,
              'contactMode': 'call',
              'responseDelayHours': 2,
            },
            requestOptions: RequestOptions(),
            statusCode: 200,
          ),
        );
        final dto = await datasource.fetchPrefs();
        expect(dto.weightUnit, 'lbs');
        expect(dto.currencyCode, 'XOF');
        expect(dto.pickupRadiusKm, 20);
        expect(dto.defaultPackageWeightKg, 30);
        expect(dto.minBidPriceEur, 5);
        expect(dto.contactMode, 'call');
        expect(dto.responseDelayHours, 2);
      },
    );

    test(
      'updatePrefs appelle PUT /users/me/business-preferences avec le DTO sérialisé',
      () async {
        const dto = UserBusinessPrefsDto(
          weightUnit: 'kg',
          currencyCode: 'EUR',
          pickupRadiusKm: 10,
          defaultPackageWeightKg: 23,
          minBidPriceEur: 0,
        );
        when(
          () =>
              mockDio.put('/users/me/business-preferences', data: dto.toJson()),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            // Le serveur renvoie l'état recalculé : la devise dérivée du pays
            // ne ressemble pas forcément à celle envoyée.
            data: const {
              'weightUnit': 'kg',
              'currencyCode': 'XOF',
              'pickupRadiusKm': 10,
              'defaultPackageWeightKg': 23,
              'minBidPriceEur': 0,
              'country': 'SN',
              'countryLocked': true,
            },
          ),
        );
        final saved = await datasource.updatePrefs(dto);
        verify(
          () =>
              mockDio.put('/users/me/business-preferences', data: dto.toJson()),
        ).called(1);
        expect(saved.currencyCode, 'XOF');
        expect(saved.country, 'SN');
        expect(saved.countryLocked, isTrue);
      },
    );
  });
}
