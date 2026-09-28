import 'package:dony/features/support/data/support_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportSummary.fromJson', () {
    test('lit un résumé complet', () {
      final summary = SupportSummary.fromJson(const {
        'unreadCount': 2,
        'openTicketCount': 1,
        'latestTicket': {
          'id': 't1',
          'subject': 'Colis bloqué',
          'lastMessagePreview': 'Nous regardons votre dossier',
          'lastMessageAt': '2026-09-29T10:15:00Z',
          'lastMessageFromAdmin': true,
          'unreadCount': 2,
        },
      });

      expect(summary.unreadCount, 2);
      expect(summary.openTicketCount, 1);
      final latest = summary.latestTicket!;
      expect(latest.id, 't1');
      expect(latest.subject, 'Colis bloqué');
      expect(latest.lastMessagePreview, 'Nous regardons votre dossier');
      expect(latest.lastMessageAt, DateTime.utc(2026, 9, 29, 10, 15));
      expect(latest.lastMessageFromAdmin, isTrue);
      expect(latest.unreadCount, 2);
    });

    test('tolère un ticket partiel (champs optionnels absents)', () {
      final summary = SupportSummary.fromJson(const {
        'unreadCount': 0,
        'latestTicket': {'id': 't2'},
      });

      expect(summary.openTicketCount, 0);
      final latest = summary.latestTicket!;
      expect(latest.subject, '');
      expect(latest.lastMessagePreview, isNull);
      expect(latest.lastMessageAt, isNull);
      expect(latest.lastMessageFromAdmin, isFalse);
      expect(latest.unreadCount, 0);
    });

    test('latestTicket null : aucune conversation', () {
      final summary = SupportSummary.fromJson(const {
        'unreadCount': 0,
        'openTicketCount': 0,
        'latestTicket': null,
      });

      expect(summary.latestTicket, isNull);
    });

    test('un corps vide donne un résumé à zéro', () {
      final summary = SupportSummary.fromJson(const {});

      expect(summary.unreadCount, 0);
      expect(summary.openTicketCount, 0);
      expect(summary.latestTicket, isNull);
    });

    test('une date illisible ou un type inattendu ne fait pas planter', () {
      final summary = SupportSummary.fromJson(const {
        'unreadCount': '3',
        'latestTicket': {
          'id': 't3',
          'lastMessageAt': 'pas une date',
          'lastMessageFromAdmin': 'oui',
        },
      });

      expect(summary.unreadCount, 0);
      expect(summary.latestTicket!.lastMessageAt, isNull);
      expect(summary.latestTicket!.lastMessageFromAdmin, isFalse);
    });
  });

  group('SupportTicket.fromJson : aperçu du dernier message', () {
    test('lit les champs d\'aperçu quand le back les envoie', () {
      final ticket = SupportTicket.fromJson(const {
        'id': 't1',
        'category': 'PAYMENT',
        'subject': 'Aide',
        'status': 'WAITING_USER',
        'lastMessagePreview': 'Pouvez-vous envoyer une photo ?',
        'lastMessageAt': '2026-09-29T08:00:00Z',
        'lastMessageFromAdmin': true,
      });

      expect(ticket.lastMessagePreview, 'Pouvez-vous envoyer une photo ?');
      expect(ticket.lastMessageFromAdmin, isTrue);
      expect(ticket.lastMessageAt, DateTime.utc(2026, 9, 29, 8));
    });

    test('ancien back : pas d\'aperçu', () {
      final ticket = SupportTicket.fromJson(const {
        'id': 't1',
        'category': 'PAYMENT',
        'subject': 'Aide',
        'status': 'NEW',
      });

      expect(ticket.lastMessagePreview, isNull);
      expect(ticket.lastMessageFromAdmin, isFalse);
    });
  });
}
