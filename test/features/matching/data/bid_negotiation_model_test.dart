import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _threadJson({
  bool withNet = true,
  String status = 'NEGOTIATING',
  bool myTurn = true,
}) => {
  'bidId': 'bid-1',
  'announcementId': 'ann-1',
  'status': status,
  // Le serveur envoie les deux ensemble : un net n'est renseigné que pour le
  // voyageur. La fixture reflète ce couplage, le modèle ne le suppose plus.
  'role': withNet ? 'TRAVELER' : 'SENDER',
  'round': 2,
  'maxRounds': 6,
  'myTurn': myTurn,
  'canCounter': true,
  'currency': 'EUR',
  'proposedGrossEur': 48.5,
  if (withNet) 'netEur': 42.0,
  if (withNet) 'commissionEur': 6.5,
  'suggestedGrossEur': 45.0,
  'weightKg': 4.5,
  'description': 'Deux pagnes et un carton de riz',
  'contentCategory': 'Vêtements',
  'gridItems': [
    {
      'id': 'grid-1',
      'label': 'Carton 10 kg',
      'unitPriceDisplayEur': 25.0,
      'quantity': 2,
    },
  ],
  'customItems': [
    {
      'id': 'custom-1',
      'label': 'Machine à coudre',
      'quantity': 1,
      'amountEur': 30.0,
    },
  ],
  'photoUrls': ['https://cdn.example/1.jpg'],
  'counterpartyName': 'Fatou S.',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2026-09-12',
  'expiresAt': '2026-08-20T10:30:00',
  'messages': [
    {
      'id': 'msg-1',
      'kind': 'PROPOSAL',
      'authorId': 'user-1',
      'proposedGrossEur': 40.0,
      'body': null,
      'createdAt': '2026-08-18T09:00:00',
    },
    {
      'id': 'msg-2',
      'kind': 'COUNTER',
      'authorId': 'user-2',
      'proposedGrossEur': 48.5,
      'body': 'Un peu plus lourd que prévu',
      'createdAt': '2026-08-18T11:00:00',
    },
  ],
};

Map<String, dynamic> _summaryJson() => {
  'bidId': 'bid-9',
  'announcementId': 'ann-9',
  'status': 'NEGOTIATING',
  'round': 1,
  'myTurn': false,
  'hasUnread': true,
  'proposedGrossEur': 33.0,
  'currency': 'XOF',
  'counterpartyName': 'Moussa D.',
  'departureCity': 'Lyon',
  'arrivalCity': 'Bamako',
  'departureDate': '2026-10-01',
  'updatedAt': '2026-08-18T12:00:00',
  'role': 'SENDER',
};

void main() {
  group('BidNegotiation.fromJson', () {
    test('lit un fil complet, vue voyageur', () {
      final thread = BidNegotiation.fromJson(_threadJson());

      expect(thread.bidId, 'bid-1');
      expect(thread.announcementId, 'ann-1');
      expect(thread.status, 'NEGOTIATING');
      expect(thread.round, 2);
      expect(thread.maxRounds, 6);
      expect(thread.canCounter, isTrue);
      expect(thread.currency, 'EUR');
      expect(thread.proposedGrossEur, 48.5);
      expect(thread.netEur, 42.0);
      expect(thread.commissionEur, 6.5);
      expect(thread.suggestedGrossEur, 45.0);
      expect(thread.weightKg, 4.5);
      expect(thread.description, 'Deux pagnes et un carton de riz');
      expect(thread.contentCategory, 'Vêtements');
      expect(thread.photoUrls, ['https://cdn.example/1.jpg']);
      expect(thread.counterpartyName, 'Fatou S.');
      expect(thread.departureCity, 'Paris');
      expect(thread.arrivalCity, 'Dakar');
      expect(thread.departureDate, DateTime(2026, 9, 12));
      expect(thread.expiresAt, DateTime(2026, 8, 20, 10, 30));
      expect(thread.messages, hasLength(2));
    });

    test('vue expediteur : netEur et commissionEur restent nuls', () {
      final thread = BidNegotiation.fromJson(_threadJson(withNet: false));

      expect(thread.netEur, isNull);
      expect(thread.commissionEur, isNull);
      expect(thread.proposedGrossEur, 48.5);
    });

    test('le role vient du serveur, pas de la presence du net', () {
      // L'ancienne deduction lisait `netEur != null`, ce qui confondait deux
      // causes : le net est tu a l'expediteur, mais AUSSI tant qu'aucun brut
      // n'a ete propose. Un voyageur sans montant basculait en vue expediteur.
      final travelerWithoutAmount = BidNegotiation.fromJson({
        'bidId': 'bid-3',
        'announcementId': 'ann-3',
        'status': 'NEGOTIATING',
        'role': 'TRAVELER',
      });

      expect(travelerWithoutAmount.netEur, isNull);
      expect(travelerWithoutAmount.isTravelerView, isTrue);
      expect(travelerWithoutAmount.viewerRole, 'traveler');
    });

    test('un serveur sans champ role est lu comme expediteur', () {
      final thread = BidNegotiation.fromJson({
        'bidId': 'bid-4',
        'announcementId': 'ann-4',
        'status': 'NEGOTIATING',
      });

      expect(thread.role, 'SENDER');
      expect(thread.isTravelerView, isFalse);
    });

    test('myTurn et isClosed derivent du statut et du tour', () {
      expect(BidNegotiation.fromJson(_threadJson()).myTurn, isTrue);
      expect(
        BidNegotiation.fromJson(_threadJson(myTurn: false)).myTurn,
        isFalse,
      );
      expect(BidNegotiation.fromJson(_threadJson()).isClosed, isFalse);
      expect(
        BidNegotiation.fromJson(
          _threadJson(status: 'AWAITING_PAYMENT'),
        ).isClosed,
        isTrue,
      );
    });

    test('tolere les champs optionnels absents', () {
      final thread = BidNegotiation.fromJson({
        'bidId': 'bid-2',
        'announcementId': 'ann-2',
        'status': 'NEGOTIATING',
      });

      expect(thread.round, 0);
      expect(thread.maxRounds, 0);
      expect(thread.myTurn, isFalse);
      expect(thread.canCounter, isFalse);
      expect(thread.currency, 'EUR');
      expect(thread.proposedGrossEur, 0);
      expect(thread.weightKg, isNull);
      expect(thread.description, isNull);
      expect(thread.gridItems, isEmpty);
      expect(thread.customItems, isEmpty);
      expect(thread.photoUrls, isEmpty);
      expect(thread.messages, isEmpty);
      expect(thread.departureDate, isNull);
      expect(thread.expiresAt, isNull);
    });
  });

  group('BidCustomItem', () {
    test('lit une ligne hors grille et calcule son total', () {
      final item = BidCustomItem.fromJson({
        'id': 'custom-1',
        'label': 'Machine à coudre',
        'quantity': 3,
        'amountEur': 30.0,
      });

      expect(item.id, 'custom-1');
      expect(item.label, 'Machine à coudre');
      expect(item.quantity, 3);
      expect(item.amountEur, 30.0);
      expect(item.totalEur, 90.0);
    });

    test('quantite absente vaut 1', () {
      final item = BidCustomItem.fromJson({
        'id': 'c',
        'label': 'Divers',
        'amountEur': 12,
      });

      expect(item.quantity, 1);
      expect(item.totalEur, 12.0);
    });
  });

  group('BidGridLine', () {
    test('lit une ligne de grille au prix expediteur', () {
      final line = BidGridLine.fromJson({
        'id': 'grid-1',
        'label': 'Carton 10 kg',
        'unitPriceDisplayEur': 25.0,
        'quantity': 2,
      });

      expect(line.id, 'grid-1');
      expect(line.label, 'Carton 10 kg');
      expect(line.unitPriceDisplayEur, 25.0);
      expect(line.quantity, 2);
      expect(line.totalEur, 50.0);
    });
  });

  group('BidNegotiationMessage', () {
    test('parse le type de message en enum', () {
      final thread = BidNegotiation.fromJson(_threadJson());

      expect(thread.messages.first.kind, BidNegotiationMessageKind.proposal);
      expect(thread.messages.last.kind, BidNegotiationMessageKind.counter);
      expect(thread.messages.last.body, 'Un peu plus lourd que prévu');
      expect(thread.messages.first.body, isNull);
      expect(thread.messages.first.authorId, 'user-1');
      expect(thread.messages.first.createdAt, DateTime(2026, 8, 18, 9));
    });

    test('un type inconnu retombe sur PROPOSAL', () {
      final message = BidNegotiationMessage.fromJson({
        'id': 'm',
        'kind': 'SOMETHING_NEW',
        'authorId': 'u',
        'createdAt': '2026-08-18T09:00:00',
      });

      expect(message.kind, BidNegotiationMessageKind.proposal);
      expect(message.proposedGrossEur, isNull);
    });

    test('les types ACCEPT et REJECT sont reconnus', () {
      expect(
        BidNegotiationMessage.fromJson({
          'id': 'm',
          'kind': 'ACCEPT',
          'authorId': 'u',
          'createdAt': '2026-08-18T09:00:00',
        }).kind,
        BidNegotiationMessageKind.accept,
      );
      expect(
        BidNegotiationMessage.fromJson({
          'id': 'm',
          'kind': 'REJECT',
          'authorId': 'u',
          'createdAt': '2026-08-18T09:00:00',
        }).kind,
        BidNegotiationMessageKind.reject,
      );
    });
  });

  group('BidNegotiationSummary.fromJson', () {
    test('lit une ligne de la liste', () {
      final summary = BidNegotiationSummary.fromJson(_summaryJson());

      expect(summary.bidId, 'bid-9');
      expect(summary.announcementId, 'ann-9');
      expect(summary.status, 'NEGOTIATING');
      expect(summary.round, 1);
      expect(summary.myTurn, isFalse);
      expect(summary.hasUnread, isTrue);
      expect(summary.proposedGrossEur, 33.0);
      expect(summary.currency, 'XOF');
      expect(summary.counterpartyName, 'Moussa D.');
      expect(summary.departureCity, 'Lyon');
      expect(summary.arrivalCity, 'Bamako');
      expect(summary.departureDate, DateTime(2026, 10));
      expect(summary.updatedAt, DateTime(2026, 8, 18, 12));
      expect(summary.role, 'SENDER');
      expect(summary.isClosed, isFalse);
    });

    test('tolere les champs optionnels absents', () {
      final summary = BidNegotiationSummary.fromJson({
        'bidId': 'b',
        'announcementId': 'a',
        'status': 'REJECTED',
      });

      expect(summary.round, 0);
      expect(summary.myTurn, isFalse);
      expect(summary.hasUnread, isFalse);
      expect(summary.proposedGrossEur, 0);
      expect(summary.currency, 'EUR');
      expect(summary.counterpartyName, isNull);
      expect(summary.departureDate, isNull);
      expect(summary.updatedAt, isNull);
      expect(summary.isClosed, isTrue);
    });
  });
}
