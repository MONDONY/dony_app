import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationModel.fromJson', () {
    test('une ligne seule : count 1, ses propres ids, deeplink en route', () {
      final m = NotificationModel.fromJson({
        'id': 'n1',
        'type': 'BID_ACCEPTED',
        'category': 'colis',
        'title': 'Demande acceptée !',
        'body': 'Karim T. accepte votre colis.',
        'deeplink': 'yadony://bids/b1',
        'groupKey': 'notif:n1',
        'data': {'type': 'BID_ACCEPTED', 'bidId': 'b1'},
        'read': false,
        'createdAt': '2026-09-03T10:00:00.000Z',
        'count': 1,
        'notificationIds': ['n1'],
      });

      expect(m.isAggregate, isFalse);
      expect(m.count, 1);
      expect(m.notificationIds, ['n1']);
      expect(m.category, 'colis');
      expect(m.deeplinkRoute, '/bids/b1');
      expect(m.groupKey, 'notif:n1');
    });

    test('une ligne agrégée : count et ids recouverts', () {
      final m = NotificationModel.fromJson({
        'id': 'latest',
        'type': 'BID_CREATED',
        'category': 'colis',
        'title': '3 demandes d\'envoi',
        'body': 'Karim T., 12 kg, Paris vers Dakar.',
        'deeplink': 'yadony://announcements/a1/bids',
        'groupKey': 'bid:announcement:a1',
        'data': {'type': 'BID_CREATED'},
        'read': false,
        'createdAt': '2026-09-03T10:00:00.000Z',
        'count': 3,
        'notificationIds': ['latest', 'n2', 'n3'],
      });

      expect(m.isAggregate, isTrue);
      expect(m.count, 3);
      expect(m.notificationIds, ['latest', 'n2', 'n3']);
      expect(m.deeplinkRoute, '/announcements/a1/bids');
    });

    test('l\'ancienne liste sans les champs du contrat reste lisible', () {
      final m = NotificationModel.fromJson({
        'id': 'n1',
        'type': 'PAYMENT_RELEASED',
        'title': 'Paiement reçu !',
        'body': '45,00 €, virement en cours sous 24 h.',
        'data': <String, dynamic>{},
        'read': true,
        'createdAt': '2026-09-03T10:00:00.000Z',
      });

      expect(m.count, 1);
      expect(m.notificationIds, ['n1']);
      expect(m.category, '');
      expect(m.deeplink, isNull);
      expect(m.deeplinkRoute, isNull);
      expect(m.isAggregate, isFalse);
    });

    test('un deeplink malformé ne donne aucune route', () {
      final m = NotificationModel.fromJson({
        'id': 'n1',
        'type': 'SYSTEM',
        'title': 't',
        'body': 'b',
        'deeplink': 'pas un lien',
        'data': <String, dynamic>{},
        'read': false,
        'createdAt': '2026-09-03T10:00:00.000Z',
      });

      expect(m.deeplinkRoute, isNull);
    });
  });

  test('copyWith(read) garde tout le reste, agrégat compris', () {
    final m = NotificationModel.fromJson({
      'id': 'latest',
      'type': 'BID_CREATED',
      'title': '3 demandes d\'envoi',
      'body': 'b',
      'groupKey': 'bid:announcement:a1',
      'data': <String, dynamic>{},
      'read': false,
      'createdAt': '2026-09-03T10:00:00.000Z',
      'count': 3,
      'notificationIds': ['latest', 'n2', 'n3'],
    });

    final read = m.copyWith(read: true);

    expect(read.read, isTrue);
    expect(read.count, 3);
    expect(read.groupKey, 'bid:announcement:a1');
    expect(read.notificationIds, ['latest', 'n2', 'n3']);
  });
}
