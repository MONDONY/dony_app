import 'package:dony/features/support/data/support_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  group('SupportPredefinedReply.fromJson', () {
    test('lit les quatre champs', () {
      final r = SupportPredefinedReply.fromJson(const {
        'code': 'PAYMENT_DELAY',
        'category': 'PAYMENT',
        'question': 'Quand suis-je payé ?',
        'answer': 'Sous 48 h.',
      });
      expect(r.code, 'PAYMENT_DELAY');
      expect(r.category, 'PAYMENT');
      expect(r.question, 'Quand suis-je payé ?');
      expect(r.answer, 'Sous 48 h.');
    });

    test('champs absents : chaînes vides, égalité par valeur', () {
      final r = SupportPredefinedReply.fromJson(const {});
      expect(
        r,
        const SupportPredefinedReply(
          code: '',
          category: '',
          question: '',
          answer: '',
        ),
      );
    });
  });

  group('SupportMessage.fromJson', () {
    test('lit la date et l’auteur', () {
      final m = SupportMessage.fromJson(const {
        'id': 'm1',
        'authorType': 'ADMIN',
        'content': 'Bonjour',
        'createdAt': '2026-02-01T09:00:00Z',
      });
      expect(m.createdAt, DateTime.utc(2026, 2, 1, 9));
      expect(m.isFromUser, isFalse);
      expect(m.attachments, isEmpty);
    });

    test('date illisible : null ; auteur absent : USER', () {
      final m = SupportMessage.fromJson(const {'createdAt': 'pas une date'});
      expect(m.createdAt, isNull);
      expect(m.isFromUser, isTrue);
      expect(m.id, '');
    });
  });

  group('SupportTicket.fromJson', () {
    test('lit les dates de création, dernier message et résolution', () {
      final t = SupportTicket.fromJson(const {
        'id': 't1',
        'category': 'PAYMENT',
        'subject': 'Remboursement',
        'status': 'RESOLVED',
        'createdAt': '2026-02-01T09:00:00Z',
        'lastMessageAt': '2026-02-02T09:00:00Z',
        'resolvedAt': '2026-02-03T09:00:00Z',
        'unreadCount': 2,
        'lastMessagePreview': 'Merci',
        'lastMessageFromAdmin': true,
        'messages': [
          {'id': 'm1', 'content': 'Salut'},
        ],
      });
      expect(t.createdAt, DateTime.utc(2026, 2, 1, 9));
      expect(t.lastMessageAt, DateTime.utc(2026, 2, 2, 9));
      expect(t.resolvedAt, DateTime.utc(2026, 2, 3, 9));
      expect(t.isResolved, isTrue);
      expect(t.unreadCount, 2);
      expect(t.lastMessagePreview, 'Merci');
      expect(t.lastMessageFromAdmin, isTrue);
      expect(t.messages.single.content, 'Salut');
    });

    test('valeurs par défaut : statut NEW, pas de dates', () {
      final t = SupportTicket.fromJson(const {});
      expect(t.status, SupportTicketStatuses.newTicket);
      expect(t.isResolved, isFalse);
      expect(t.resolvedAt, isNull);
      expect(t.lastMessageFromAdmin, isFalse);
      expect(t.unreadCount, 0);
    });
  });

  group('SupportSummaryTicket', () {
    test('égalité et hashCode par valeur', () {
      final a = SupportSummaryTicket.fromJson(const {
        'id': 't1',
        'subject': 'Colis',
        'lastMessagePreview': 'Ok',
        'lastMessageAt': '2026-02-02T09:00:00Z',
        'lastMessageFromAdmin': true,
        'unreadCount': 1,
      });
      final b = SupportSummaryTicket(
        id: 't1',
        subject: 'Colis',
        lastMessagePreview: 'Ok',
        lastMessageAt: DateTime.utc(2026, 2, 2, 9),
        lastMessageFromAdmin: true,
        unreadCount: 1,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const SupportSummaryTicket(id: 't1')));
    });
  });

  test('SupportTicketDraft : égalité de valeur, origine comprise', () {
    SupportTicketDraft make({String subject = 'Sujet', String? origin}) =>
        // ignore: prefer_const_constructors
        SupportTicketDraft(
          category: 'PACKAGE',
          subject: subject,
          message: 'Bonjour',
          origin: origin,
        );
    expectValueEquality(make, [
      make(subject: 'Autre'),
      make(origin: 'team_cancelled_parcel'),
    ]);
  });
}
