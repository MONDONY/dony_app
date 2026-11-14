import 'package:dony/features/matching/data/models/transport_mode.dart';
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
  group('ConversationModel.tripTransportMode', () {
    test('absent (back prod pas encore déployé) : null', () {
      expect(ConversationModel.fromJson(_json()).tripTransportMode, isNull);
    });

    test('CAR : route', () {
      final model = ConversationModel.fromJson(
        _json({'tripTransportMode': 'CAR'}),
      );
      expect(model.tripTransportMode, TransportMode.car);
    });

    test('valeur inconnue ou mal typée : null', () {
      expect(
        ConversationModel.fromJson(
          _json({'tripTransportMode': 'ROCKET'}),
        ).tripTransportMode,
        isNull,
      );
      expect(
        ConversationModel.fromJson(
          _json({'tripTransportMode': 3}),
        ).tripTransportMode,
        isNull,
      );
    });

    test('copyWith conserve le mode', () {
      final model = ConversationModel.fromJson(
        _json({'tripTransportMode': 'BOAT'}),
      );
      expect(
        model.copyWith(unreadCount: 1).tripTransportMode,
        TransportMode.boat,
      );
    });
  });
}
