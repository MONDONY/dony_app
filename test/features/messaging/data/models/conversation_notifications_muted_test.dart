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
  group('ConversationModel.notificationsMuted (FLUTTER-CM)', () {
    test('absent (ancien back) : faux', () {
      expect(ConversationModel.fromJson(_json()).notificationsMuted, isFalse);
    });

    test('true servi par le back : vrai', () {
      final model = ConversationModel.fromJson(
        _json({'notificationsMuted': true}),
      );
      expect(model.notificationsMuted, isTrue);
    });

    test('valeur nulle ou mal typée : faux', () {
      expect(
        ConversationModel.fromJson(
          _json({'notificationsMuted': null}),
        ).notificationsMuted,
        isFalse,
      );
      expect(
        ConversationModel.fromJson(
          _json({'notificationsMuted': 'true'}),
        ).notificationsMuted,
        isFalse,
      );
    });

    test('copyWith pose la sourdine et conserve le reste', () {
      final model = ConversationModel.fromJson(
        _json({'deletedBySelf': true, 'callAvailable': true}),
      );
      final muted = model.copyWith(notificationsMuted: true);
      expect(muted.notificationsMuted, isTrue);
      expect(muted.deletedBySelf, isTrue);
      expect(muted.callAvailable, isTrue);
      expect(muted.copyWith(unreadCount: 3).notificationsMuted, isTrue);
      expect(
        muted.copyWith(notificationsMuted: false).notificationsMuted,
        isFalse,
      );
    });
  });
}
