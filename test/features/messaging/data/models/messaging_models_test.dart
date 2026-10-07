import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  group('MessageModel.replyToId (FLUTTER-86)', () {
    Map<String, dynamic> doc([Object? replyToId]) => {
      'senderId': 'uid-a',
      'body': 'Oui',
      'type': 'TEXT',
      'sentAt': '2026-10-07T10:00:00.000Z',
      'replyToId': ?replyToId,
    };

    test('sans replyToId (ancien format) : null', () {
      expect(MessageModel.fromFirestore('m', doc()).replyToId, isNull);
    });

    test('avec replyToId : lu tel quel', () {
      expect(
        MessageModel.fromFirestore('m', doc('AbC123xyz')).replyToId,
        'AbC123xyz',
      );
    });

    test('valeur hors forme (type, chemin, longueur) : ignorée', () {
      for (final bad in [42, '', 'a/b', 'x' * 41, 'id-avec-tiret']) {
        expect(
          MessageModel.fromFirestore('m', doc(bad)).replyToId,
          isNull,
          reason: '$bad',
        );
      }
    });
  });

  group('MessageModel.fromFirestore', () {
    test('parses TEXT message with all fields', () {
      final m = MessageModel.fromFirestore('id-1', {
        'senderId': 'uid-a',
        'body': 'Hello',
        'imageUrl': null,
        'type': 'TEXT',
        'sentAt': '2026-04-30T10:00:00.000',
        'readAt': null,
        'deletedAt': null,
      });
      expect(m.id, 'id-1');
      expect(m.senderId, 'uid-a');
      expect(m.body, 'Hello');
      expect(m.type, MessageType.text);
      expect(m.isDeleted, false);
      expect(m.readAt, isNull);
    });

    test('parses IMAGE message', () {
      final m = MessageModel.fromFirestore('id-2', {
        'senderId': 'uid-b',
        'body': null,
        'imageUrl': 'https://example.com/img.jpg',
        'type': 'IMAGE',
        'sentAt': '2026-04-30T11:00:00.000',
        'readAt': null,
      });
      expect(m.type, MessageType.image);
      expect(m.imageUrl, 'https://example.com/img.jpg');
      expect(m.body, isNull);
    });

    test('parses SYSTEM message', () {
      final m = MessageModel.fromFirestore('id-3', {
        'senderId': 'system',
        'body': 'Conversation démarrée',
        'imageUrl': null,
        'type': 'SYSTEM',
        'sentAt': '2026-04-30T09:00:00.000',
        'readAt': null,
      });
      expect(m.type, MessageType.system);
    });

    test('defaults unknown type to text', () {
      final m = MessageModel.fromFirestore('id-4', {
        'senderId': 'uid-a',
        'body': 'test',
        'type': 'UNKNOWN_TYPE',
        'sentAt': '2026-04-30T12:00:00.000',
        'readAt': null,
      });
      expect(m.type, MessageType.text);
    });

    test('parses readAt when present', () {
      final m = MessageModel.fromFirestore('id-5', {
        'senderId': 'uid-a',
        'body': 'read msg',
        'type': 'TEXT',
        'sentAt': '2026-04-30T10:00:00.000',
        'readAt': '2026-04-30T10:05:00.000',
      });
      expect(m.readAt, isNotNull);
      expect(m.readAt!.minute, 5);
    });

    test('isDeleted is true when deletedAt is set', () {
      final m = MessageModel.fromFirestore('id-6', {
        'senderId': 'uid-a',
        'body': null,
        'type': 'TEXT',
        'sentAt': '2026-04-30T10:00:00.000',
        'readAt': null,
        'deletedAt': '2026-04-30T10:10:00.000',
      });
      expect(m.isDeleted, true);
    });

    test('falls back to DateTime.now() when sentAt is null', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final m = MessageModel.fromFirestore('id-7', {
        'senderId': 'uid-a',
        'body': 'msg',
        'type': 'TEXT',
        'sentAt': null,
        'readAt': null,
      });
      expect(m.sentAt.isAfter(before), true);
    });

    test('falls back to DateTime.now() when sentAt is unparseable', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final m = MessageModel.fromFirestore('id-8', {
        'senderId': 'uid-a',
        'body': 'msg',
        'type': 'TEXT',
        'sentAt': 'not-a-date',
        'readAt': null,
      });
      expect(m.sentAt.isAfter(before), true);
    });

    test('falls back to DateTime.now() when sentAt is a non-String type', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final m = MessageModel.fromFirestore('id-9', {
        'senderId': 'uid-a',
        'body': 'msg',
        'type': 'TEXT',
        'sentAt': 1234567890,
        'readAt': null,
      });
      expect(m.sentAt.isAfter(before), true);
    });
  });

  group('ParticipantModel', () {
    test('fromJson parses id and name', () {
      final p = ParticipantModel.fromJson({'id': 'uid-x', 'name': 'Alice'});
      expect(p.id, 'uid-x');
      expect(p.name, 'Alice');
      expect(p.avatarUrl, isNull);
    });

    test('fromJson parses avatarUrl when present', () {
      final p = ParticipantModel.fromJson({
        'id': 'uid-y',
        'name': 'Bob',
        'avatarUrl': 'https://example.com/avatar.jpg',
      });
      expect(p.avatarUrl, 'https://example.com/avatar.jpg');
    });
  });

  group('ConversationModel', () {
    test('fromJson parses all required fields', () {
      final c = ConversationModel.fromJson({
        'id': 'conv-1',
        'bidId': 'bid-1',
        'firestoreConversationId': 'conv_bid1',
        'otherParticipant': {'id': 'uid-z', 'name': 'Charlie'},
        'lastMessagePreview': 'Bonjour',
        'lastMessageAt': '2026-04-30T10:00:00.000',
        'hasUnread': true,
      });
      expect(c.id, 'conv-1');
      expect(c.bidId, 'bid-1');
      expect(c.firestoreConversationId, 'conv_bid1');
      expect(c.otherParticipant.name, 'Charlie');
      expect(c.lastMessagePreview, 'Bonjour');
      expect(c.lastMessageAt, isNotNull);
      expect(c.hasUnread, true);
    });

    test('fromJson handles null optional fields', () {
      final c = ConversationModel.fromJson({
        'id': 'conv-2',
        'bidId': 'bid-2',
        'firestoreConversationId': 'conv_bid2',
        'otherParticipant': {'id': 'uid-w', 'name': 'Dave'},
      });
      expect(c.lastMessagePreview, isNull);
      expect(c.lastMessageAt, isNull);
      expect(c.hasUnread, false);
    });

    test('copyWith changes hasUnread', () {
      const c = ConversationModel(
        id: 'conv-3',
        bidId: 'bid-3',
        firestoreConversationId: 'conv_bid3',
        otherParticipant: ParticipantModel(id: 'uid-v', name: 'Eve'),
      );
      final updated = c.copyWith(hasUnread: true);
      expect(updated.hasUnread, true);
      expect(updated.id, 'conv-3');
    });

    test('copyWith preserves hasUnread when not passed', () {
      const c = ConversationModel(
        id: 'conv-4',
        bidId: 'bid-4',
        firestoreConversationId: 'conv_bid4',
        otherParticipant: ParticipantModel(id: 'uid-u', name: 'Frank'),
        hasUnread: true,
      );
      final same = c.copyWith();
      expect(same.hasUnread, true);
    });

    // Régression F1 : 'd MMM' fixe → DateFormat.MMMd(AppL10n.localeName).
    // Modèle sans BuildContext : la langue vient de Intl.defaultLocale.
    test(
      'tripLabel formate la date en français (rendu identique à l\'ancien motif)',
      () {
        final c = ConversationModel(
          id: 'conv-trip',
          bidId: 'bid-trip',
          firestoreConversationId: 'conv_bid_trip',
          otherParticipant: const ParticipantModel(id: 'uid-t', name: 'Trip'),
          tripOrigin: 'Paris',
          tripDestination: 'Dakar',
          tripDate: DateTime(2026, 10, 6, 14, 5),
          tripWeightKg: 5,
        );
        expect(c.tripLabel, 'Paris → Dakar · 6 oct. · 5 kg');
      },
    );

    test('tripLabel formate la date en anglais', () {
      useEnglish();
      final c = ConversationModel(
        id: 'conv-trip-en',
        bidId: 'bid-trip-en',
        firestoreConversationId: 'conv_bid_trip_en',
        otherParticipant: const ParticipantModel(id: 'uid-t', name: 'Trip'),
        tripOrigin: 'Paris',
        tripDestination: 'Dakar',
        tripDate: DateTime(2026, 10, 6, 14, 5),
        tripWeightKg: 5,
      );
      expect(c.tripLabel, 'Paris → Dakar · Oct 6 · 5 kg');
    });
  });

  group('ConversationModel.kind (lot 3C)', () {
    Map<String, dynamic> json({
      Object? kind,
      String? role,
      Object? viewerRole,
    }) => {
      'id': 'conv-k',
      'bidId': 'bid-k',
      'firestoreConversationId': 'rconv_bid-k',
      'otherParticipant': {'id': 'uid-k', 'name': 'Awa', 'role': ?role},
      'kind': ?kind,
      'viewerRole': ?viewerRole,
    };

    test('viewerRole fait foi sur la déduction par le rôle', () {
      final recipient = ConversationModel.fromJson(
        json(
          kind: 'RECIPIENT_TRAVELER',
          role: 'Destinataire',
          viewerRole: 'RECIPIENT',
        ),
      );
      expect(recipient.viewerRole, 'RECIPIENT');
      expect(recipient.viewerIsRecipient, isTrue);

      final traveler = ConversationModel.fromJson(
        json(
          kind: 'RECIPIENT_TRAVELER',
          role: 'Voyageur',
          viewerRole: 'traveler',
        ),
      );
      expect(traveler.viewerRole, 'TRAVELER');
      expect(traveler.viewerIsRecipient, isFalse);
      expect(traveler.copyWith(hasUnread: true).viewerRole, 'TRAVELER');
    });

    test('viewerRole absent, vide ou inconnu : repli sur le rôle', () {
      for (final value in [null, ' ', 42, 'AUTRE']) {
        final c = ConversationModel.fromJson(
          json(
            kind: 'RECIPIENT_TRAVELER',
            role: 'Destinataire',
            viewerRole: value,
          ),
        );
        expect(c.viewerIsRecipient, isFalse, reason: '$value');
      }
      expect(ConversationModel.fromJson(json()).viewerRole, isNull);
      // Fil expéditeur ↔ voyageur : jamais destinataire, quel que soit le champ.
      expect(
        ConversationModel.fromJson(
          json(viewerRole: 'RECIPIENT'),
        ).viewerIsRecipient,
        isFalse,
      );
    });

    test('kind absent (back antérieur) -> SENDER_TRAVELER', () {
      final c = ConversationModel.fromJson(json());
      expect(c.kind, ConversationModel.kindSenderTraveler);
      expect(c.isRecipientConversation, isFalse);
      expect(c.viewerIsRecipient, isFalse);
    });

    test('kind vide ou d\'un autre type -> SENDER_TRAVELER', () {
      expect(
        ConversationModel.fromJson(json(kind: '  ')).kind,
        ConversationModel.kindSenderTraveler,
      );
      expect(
        ConversationModel.fromJson(json(kind: 42)).kind,
        ConversationModel.kindSenderTraveler,
      );
    });

    test('RECIPIENT_TRAVELER vu par le voyageur', () {
      final c = ConversationModel.fromJson(
        json(kind: 'RECIPIENT_TRAVELER', role: 'Destinataire'),
      );
      expect(c.isRecipientConversation, isTrue);
      expect(c.otherParticipant.isRecipientRole, isTrue);
      expect(c.viewerIsRecipient, isFalse);
    });

    test('RECIPIENT_TRAVELER vu par le destinataire', () {
      final c = ConversationModel.fromJson(
        json(kind: 'RECIPIENT_TRAVELER', role: 'Voyageur'),
      );
      expect(c.isRecipientConversation, isTrue);
      expect(c.viewerIsRecipient, isTrue);
    });

    test('copyWith conserve le type', () {
      final c = ConversationModel.fromJson(
        json(kind: 'RECIPIENT_TRAVELER', role: 'Recipient'),
      ).copyWith(hasUnread: true);
      expect(c.isRecipientConversation, isTrue);
      expect(c.otherParticipant.isRecipientRole, isTrue);
    });
  });

  group('ConversationModel.callAvailable (appels audio)', () {
    Map<String, dynamic> json([Object? callAvailable]) => {
      'id': 'conv-c',
      'bidId': 'bid-c',
      'firestoreConversationId': 'conv_bid-c',
      'otherParticipant': {'id': 'uid-c', 'name': 'Awa'},
      'callAvailable': ?callAvailable,
    };

    test('lu depuis le back', () {
      expect(ConversationModel.fromJson(json(true)).callAvailable, isTrue);
    });

    test('ancien back sans le champ : faux', () {
      expect(ConversationModel.fromJson(json()).callAvailable, isFalse);
    });

    test('valeur non booléenne ignorée', () {
      expect(ConversationModel.fromJson(json('yes')).callAvailable, isFalse);
    });

    test('copyWith (mise à jour des non-lus) le conserve', () {
      final c = ConversationModel.fromJson(json(true));
      expect(c.copyWith(hasUnread: true).callAvailable, isTrue);
    });
  });
}
