import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/subscriptions/data/subscriptions_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

void main() {
  late MockApiClient client;
  late MockDio dio;
  late SubscriptionsRemoteDatasource ds;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    ds = SubscriptionsRemoteDatasource(client);
  });

  test('getMySubscriptions parse la liste', () async {
    when(() => dio.get('/me/subscriptions')).thenAnswer(
      (_) async => _ok([
        {
          'travelerId': 't1',
          'travelerName': 'Ibrahima D',
          'isProAccount': true,
          'averageRating': 4.8,
          'ongoingTripsCount': 2,
          'pushEnabled': false,
          'hasNew': true,
          'lastAnnouncement': {
            'announcementId': 'a1',
            'departureCity': 'Paris',
            'arrivalCity': 'Dakar',
            'pricePerKg': 8.0,
            'publishedAt': '2026-05-25T10:00:00',
          },
        },
      ], '/me/subscriptions'),
    );

    final list = await ds.getMySubscriptions();
    expect(list, hasLength(1));
    expect(list.first.travelerName, 'Ibrahima D');
    expect(list.first.lastAnnouncement!.arrivalCity, 'Dakar');
  });

  test('getMySubscriptions fallback sur "Voyageur" si travelerName est null',
      () async {
    when(() => dio.get('/me/subscriptions')).thenAnswer(
      (_) async => _ok([
        {
          'travelerId': 't2',
          'travelerName': null,
          'isProAccount': false,
          'averageRating': null,
          'ongoingTripsCount': 0,
          'pushEnabled': false,
          'hasNew': false,
          'lastAnnouncement': null,
        },
      ], '/me/subscriptions'),
    );

    final list = await ds.getMySubscriptions();
    expect(list, hasLength(1));
    expect(list.first.travelerName, 'Voyageur');
  });

  test('getStatus parse subscribed/pushEnabled', () async {
    when(() => dio.get('/travelers/t1/subscription')).thenAnswer(
      (_) async => _ok({
        'subscribed': true,
        'pushEnabled': false,
      }, '/travelers/t1/subscription'),
    );
    final s = await ds.getStatus('t1');
    expect(s.subscribed, true);
    expect(s.pushEnabled, false);
  });

  test('subscribe POST', () async {
    when(
      () => dio.post('/travelers/t1/subscribe'),
    ).thenAnswer((_) async => _ok(null, 'x'));
    await ds.subscribe('t1');
    verify(() => dio.post('/travelers/t1/subscribe')).called(1);
  });

  test('unsubscribe DELETE', () async {
    when(
      () => dio.delete('/travelers/t1/subscribe'),
    ).thenAnswer((_) async => _ok(null, 'x'));
    await ds.unsubscribe('t1');
    verify(() => dio.delete('/travelers/t1/subscribe')).called(1);
  });

  test('setPush PUT renvoie le statut', () async {
    when(
      () => dio.put('/travelers/t1/subscribe/push', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => _ok({'subscribed': true, 'pushEnabled': true}, 'x'),
    );
    final s = await ds.setPush('t1', true);
    expect(s.pushEnabled, true);
  });

  test('markSeen POST', () async {
    when(
      () => dio.post('/me/subscriptions/t1/mark-seen'),
    ).thenAnswer((_) async => _ok(null, 'x'));
    await ds.markSeen('t1');
    verify(() => dio.post('/me/subscriptions/t1/mark-seen')).called(1);
  });

  test('getTravelerAnnouncements parse', () async {
    when(() => dio.get('/travelers/t1/announcements')).thenAnswer(
      (_) async => _ok([
        {
          'id': 'a1',
          'departureCity': 'Paris',
          'arrivalCity': 'Dakar',
          'departureDate': '2026-06-01',
          'pricePerKg': 8.0,
          'availableKg': 5.0,
          'status': 'ACTIVE',
        },
      ], '/travelers/t1/announcements'),
    );
    final list = await ds.getTravelerAnnouncements('t1');
    expect(list.single.departureCity, 'Paris');
  });
}
