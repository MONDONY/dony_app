import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/notifications/data/notification_detail.dart';
import 'package:dony/features/notifications/data/notification_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  group('NotificationDetail', () {
    test('le texte est le corps complet quand il existe', () {
      final d = NotificationDetail.fromJson({
        'id': 'a1',
        'type': 'ADMIN_BROADCAST',
        'category': 'annonce',
        'title': 'Maintenance',
        'body': 'Le service sera interrompu ce soir de 22 h à…',
        'fullBody': 'Le service sera interrompu ce soir de 22 h à 23 h.',
        'read': false,
        'createdAt': '2026-09-03T10:00:00.000Z',
      });

      expect(d.text, 'Le service sera interrompu ce soir de 22 h à 23 h.');
      expect(d.category, 'annonce');
      expect(d.read, isFalse);
    });

    test('sans corps complet, le corps court fait foi', () {
      final d = NotificationDetail.fromJson({
        'id': 'n1',
        'type': 'PAYMENT_RELEASED',
        'title': 'Paiement reçu !',
        'body': '45,00 €, virement en cours sous 24 h.',
        'read': true,
        'createdAt': '2026-09-03T10:00:00.000Z',
      });

      expect(d.text, '45,00 €, virement en cours sous 24 h.');
      expect(d.fullBody, isNull);
      expect(d.category, '');
    });
  });

  test('fetchDetail appelle /notifications/{id}', () async {
    final apiClient = MockApiClient();
    final dio = MockDio();
    when(() => apiClient.dio).thenReturn(dio);
    when(() => dio.get('/notifications/a1')).thenAnswer(
      (_) async => Response(
        data: {
          'id': 'a1',
          'type': 'ADMIN_BROADCAST',
          'category': 'annonce',
          'title': 'Maintenance',
          'body': 'Court.',
          'fullBody': 'Complet.',
          'read': false,
          'createdAt': '2026-09-03T10:00:00.000Z',
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/notifications/a1'),
      ),
    );

    final d = await NotificationRemoteDatasource(apiClient).fetchDetail('a1');

    expect(d.id, 'a1');
    expect(d.text, 'Complet.');
  });
}
