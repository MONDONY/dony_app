import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/profile/data/models/open_listing.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'models/open_listing_test.dart' show requestJson, tripJson;

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: '/users/u1/open-listings'),
);

void main() {
  late _MockDio dio;
  late ProfileRepository repo;

  setUp(() {
    dio = _MockDio();
    final client = _MockApiClient();
    when(() => client.dio).thenReturn(dio);
    repo = ProfileRepository(client);
  });

  test('lit les trajets et les demandes dans l\'ordre du serveur', () async {
    when(() => dio.get('/users/u1/open-listings')).thenAnswer(
      (_) async => _ok([
        {
          'kind': 'REQUEST',
          'publishedAt': '2026-10-21T18:00:00',
          'request': requestJson(),
        },
        {
          'kind': 'TRIP',
          'publishedAt': '2026-10-20T09:00:00',
          'trip': tripJson(),
        },
      ]),
    );

    final items = await repo.getOpenListings('u1');

    expect(items, hasLength(2));
    expect(items[0], isA<OpenRequestListing>());
    expect(items[1], isA<OpenTripListing>());
  });

  test(
    'écarte un élément illisible ou inconnu sans perdre les autres',
    () async {
      when(() => dio.get('/users/u1/open-listings')).thenAnswer(
        (_) async => _ok([
          {'kind': 'TRIP', 'publishedAt': '2026-10-20T09:00:00', 'trip': {}},
          {'kind': 'BUNDLE', 'publishedAt': '2026-10-20T09:00:00'},
          {
            'kind': 'TRIP',
            'publishedAt': '2026-10-20T09:00:00',
            'trip': tripJson(),
          },
        ]),
      );

      final items = await repo.getOpenListings('u1');

      expect(items, hasLength(1));
      expect(items.single, isA<OpenTripListing>());
    },
  );

  test('une erreur réseau remonte en exception applicative', () async {
    when(() => dio.get('/users/u1/open-listings')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/users/u1/open-listings'),
        response: Response(
          statusCode: 404,
          requestOptions: RequestOptions(path: '/users/u1/open-listings'),
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(repo.getOpenListings('u1'), throwsA(anything));
  });
}
