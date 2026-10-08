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
  group('ConversationModel.parcelStatus / returnPending (FLUTTER-EZ)', () {
    test('absents (ancien back) : pas de statut, pas de retour', () {
      final model = ConversationModel.fromJson(_json());
      expect(model.parcelStatus, isNull);
      expect(model.returnPending, isFalse);
    });

    test('servis par le back : lus tels quels, statut normalisé', () {
      final model = ConversationModel.fromJson(
        _json({'parcelStatus': ' handed_over ', 'returnPending': true}),
      );
      expect(model.parcelStatus, 'HANDED_OVER');
      expect(model.returnPending, isTrue);
    });

    test('valeurs vides ou mal typées : ignorées', () {
      final model = ConversationModel.fromJson(
        _json({'parcelStatus': '  ', 'returnPending': 'true'}),
      );
      expect(model.parcelStatus, isNull);
      expect(model.returnPending, isFalse);
      expect(
        ConversationModel.fromJson(_json({'parcelStatus': 3})).parcelStatus,
        isNull,
      );
    });

    test('copyWith conserve l\'état du colis', () {
      final model = ConversationModel.fromJson(
        _json({'parcelStatus': 'CANCELLED', 'returnPending': true}),
      );
      final copy = model.copyWith(unreadCount: 2, hasUnread: true);
      expect(copy.parcelStatus, 'CANCELLED');
      expect(copy.returnPending, isTrue);
    });
  });
}
