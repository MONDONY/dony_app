import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/likes/data/datasources/trip_like_remote_datasource.dart';
import 'package:dony/features/likes/data/models/trip_like_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

void main() {
  late _MockApiClient client;
  late _MockDio dio;
  late TripLikeRemoteDatasource ds;

  setUp(() {
    client = _MockApiClient();
    dio = _MockDio();
    when(() => client.dio).thenReturn(dio);
    ds = TripLikeRemoteDatasource(client);
  });

  test('like appelle PUT /announcements/<id>/like et lit le corps', () async {
    when(() => dio.put('/announcements/t1/like')).thenAnswer(
      (_) async =>
          _ok({'likeCount': 4, 'likedByMe': true}, '/announcements/t1/like'),
    );

    final s = await ds.like('t1');

    expect(s, const TripLikeStatus(likeCount: 4, likedByMe: true));
    verify(() => dio.put('/announcements/t1/like')).called(1);
  });

  test(
    'unlike appelle DELETE /announcements/<id>/like et lit le corps',
    () async {
      when(() => dio.delete('/announcements/t1/like')).thenAnswer(
        (_) async =>
            _ok({'likeCount': 3, 'likedByMe': false}, '/announcements/t1/like'),
      );

      final s = await ds.unlike('t1');

      expect(s, const TripLikeStatus(likeCount: 3, likedByMe: false));
      verify(() => dio.delete('/announcements/t1/like')).called(1);
    },
  );

  test('fromJson tolère des champs absents', () {
    expect(
      TripLikeStatus.fromJson(const {}),
      const TripLikeStatus(likeCount: 0, likedByMe: false),
    );
  });

  test('propage les erreurs réseau', () async {
    when(
      () => dio.put(any()),
    ).thenThrow(DioException(requestOptions: RequestOptions(path: '/x')));
    expect(() => ds.like('t1'), throwsA(isA<DioException>()));
  });
}
