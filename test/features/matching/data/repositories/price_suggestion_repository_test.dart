import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/datasources/price_suggestion_remote_datasource.dart';
import 'package:dony/features/matching/data/models/trip_price_suggestion.dart';
import 'package:dony/features/matching/data/repositories/price_suggestion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

const _path = '/announcements/price-suggestions';

Response<Object?> _ok(Object? data) => Response<Object?>(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: _path),
);

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(path: _path),
  response: Response<Object?>(
    statusCode: code,
    requestOptions: RequestOptions(path: _path),
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  late _MockDio dio;
  late PriceSuggestionRemoteDatasource datasource;
  late PriceSuggestionRepository repository;

  setUp(() {
    final client = _MockApiClient();
    dio = _MockDio();
    when(() => client.dio).thenReturn(dio);
    datasource = PriceSuggestionRemoteDatasource(client);
    repository = PriceSuggestionRepository(datasource);
  });

  void stubGet(Future<Response<Object?>> Function() answer) {
    when(
      () => dio.get<Object?>(
        _path,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) => answer());
  }

  group('PriceSuggestionRemoteDatasource', () {
    test('appelle la route avec la route et la devise', () async {
      stubGet(
        () async => _ok({
          'currency': 'EUR',
          'pricePerKg': 8,
          'sampleSize': 12,
          'items': [
            {'label': 'Téléphone', 'unitPrice': 15, 'sampleSize': 5},
          ],
        }),
      );

      final result = await datasource.getSuggestions(
        departureCity: 'Paris',
        arrivalCity: 'Abidjan',
        currency: 'EUR',
      );

      verify(
        () => dio.get<Object?>(
          _path,
          queryParameters: {
            'departureCity': 'Paris',
            'arrivalCity': 'Abidjan',
            'currency': 'EUR',
          },
        ),
      ).called(1);
      expect(
        result,
        const TripPriceSuggestion(
          currency: 'EUR',
          pricePerKg: 8,
          sampleSize: 12,
          items: [
            TripPriceSuggestionItem(
              label: 'Téléphone',
              unitPrice: 15,
              sampleSize: 5,
            ),
          ],
        ),
      );
    });

    test('réponse qui n\'est pas un objet : FormatException', () async {
      stubGet(() async => _ok(const ['x']));
      await expectLater(
        datasource.getSuggestions(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          currency: 'EUR',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PriceSuggestionRepository — tolérance à l\'ancien back', () {
    test('succès : la suggestion est rendue', () async {
      stubGet(
        () async =>
            _ok({'currency': 'XOF', 'pricePerKg': 2500, 'sampleSize': 4}),
      );
      final result = await repository.getSuggestions(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currency: 'XOF',
      );
      expect(result?.pricePerKg, 2500);
      expect(result?.currency, 'XOF');
      expect(result?.items, isEmpty);
    });

    test('404 (back pas encore déployé) : null, aucune exception', () async {
      stubGet(() => Future.error(_status(404)));
      final result = await repository.getSuggestions(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currency: 'EUR',
      );
      expect(result, isNull);
    });

    test('erreur réseau : null', () async {
      stubGet(
        () => Future.error(
          DioException(
            requestOptions: RequestOptions(path: _path),
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      final result = await repository.getSuggestions(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currency: 'EUR',
      );
      expect(result, isNull);
    });

    test('pricePerKg null (moins de 3 trajets) : gardé nul', () async {
      stubGet(
        () async => _ok({
          'currency': 'EUR',
          'pricePerKg': null,
          'sampleSize': 2,
          'items': <Object?>[],
        }),
      );
      final result = await repository.getSuggestions(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        currency: 'EUR',
      );
      expect(result, isNotNull);
      expect(result!.pricePerKg, isNull);
      expect(result.sampleSize, 2);
    });
  });

  group('TripPriceSuggestion.fromJson', () {
    test('éléments incomplets ignorés, devise par défaut celle demandée', () {
      final s = TripPriceSuggestion.fromJson(const {
        'pricePerKg': 0,
        'items': [
          {'label': 'Téléphone', 'unitPrice': 15},
          {'label': '', 'unitPrice': 10},
          {'label': 'Livre'},
          {'label': 'Sac', 'unitPrice': -1},
          'nimporte',
        ],
      }, requestedCurrency: 'EUR');
      expect(s.currency, 'EUR');
      expect(s.pricePerKg, isNull);
      expect(s.sampleSize, 0);
      expect(s.items, const [
        TripPriceSuggestionItem(label: 'Téléphone', unitPrice: 15),
      ]);
    });

    test('devise en minuscules normalisée', () {
      final s = TripPriceSuggestion.fromJson(const {
        'currency': 'xof',
      }, requestedCurrency: 'EUR');
      expect(s.currency, 'XOF');
    });
  });
}
