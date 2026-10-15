import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json([Map<String, dynamic> extra = const {}]) => {
  'id': 'c1',
  'bidId': 'b1',
  'firestoreConversationId': 'conv_b1',
  'otherParticipant': {'id': 'u2', 'name': 'Awa'},
  ...extra,
};

void main() {
  group('ConversationModel : effacement 3 jours après la livraison', () {
    test('absents (ancien back) : rien de prévu, fil ouvert', () {
      final model = ConversationModel.fromJson(_json());
      expect(model.deliveredAt, isNull);
      expect(model.messagesPurgeAt, isNull);
      expect(model.messagesPurged, isFalse);
      expect(model.isWriteClosed, isFalse);
    });

    test('dates du back sans fuseau : lues en UTC', () {
      final model = ConversationModel.fromJson(
        _json({
          'deliveredAt': '2026-10-15T10:00:00',
          'messagesPurgeAt': '2026-10-18T10:00:00',
        }),
      );
      expect(model.deliveredAt, DateTime.utc(2026, 10, 15, 10));
      expect(model.messagesPurgeAt, DateTime.utc(2026, 10, 18, 10));
      expect(model.messagesPurgeAt!.isUtc, isTrue);
    });

    test('fil purgé : fermé à l’écriture, conservé par copyWith', () {
      final model = ConversationModel.fromJson(_json({'messagesPurged': true}));
      expect(model.messagesPurged, isTrue);
      expect(model.isWriteClosed, isTrue);
      final copy = model.copyWith(hasUnread: true);
      expect(copy.messagesPurged, isTrue);
    });

    test('valeurs vides ou illisibles : ignorées', () {
      final model = ConversationModel.fromJson(
        _json({
          'deliveredAt': '  ',
          'messagesPurgeAt': 'pas une date',
          'messagesPurged': 'true',
        }),
      );
      expect(model.deliveredAt, isNull);
      expect(model.messagesPurgeAt, isNull);
      expect(model.messagesPurged, isFalse);
    });

    test('lecture seule classique : aussi fermé à l’écriture', () {
      final model = ConversationModel.fromJson(_json({'readOnly': true}));
      expect(model.isWriteClosed, isTrue);
    });
  });
}
