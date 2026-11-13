import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({Map<String, dynamic> extra = const {}}) => {
  'id': 'c1',
  'firestoreConversationId': 'fs1',
  'otherParticipant': {'id': 'u2', 'name': 'Awa'},
  ...extra,
};

void main() {
  group('ConversationModel : conversation de question', () {
    test('lit kind, announcementId, limite et quota levé, sans bidId', () {
      final model = ConversationModel.fromJson(
        _json(
          extra: {
            'kind': 'INQUIRY',
            'announcementId': 'a1',
            'inquiryMessageLimit': 10,
            'inquiryQuotaLifted': false,
          },
        ),
      );

      expect(model.bidId, isNull);
      expect(model.announcementId, 'a1');
      expect(model.kind, 'INQUIRY');
      expect(model.inquiryMessageLimit, 10);
      expect(model.inquiryQuotaLifted, isFalse);
      expect(model.isInquiry, isTrue);
      expect(model.inquiryLimited, isTrue);
    });

    test('quota levé : plus limité', () {
      final model = ConversationModel.fromJson(
        _json(
          extra: {
            'kind': 'INQUIRY',
            'announcementId': 'a1',
            'inquiryMessageLimit': 10,
            'inquiryQuotaLifted': true,
          },
        ),
      );

      expect(model.isInquiry, isTrue);
      expect(model.inquiryLimited, isFalse);
    });

    test('conversation de colis : bidId lu, pas une question', () {
      final model = ConversationModel.fromJson(_json(extra: {'bidId': 'b1'}));

      expect(model.bidId, 'b1');
      expect(model.isInquiry, isFalse);
      expect(model.inquiryLimited, isFalse);
      expect(model.announcementId, isNull);
      expect(model.inquiryMessageLimit, isNull);
      expect(model.inquiryQuotaLifted, isFalse);
    });

    test('copyWith conserve les champs de question', () {
      final model = ConversationModel.fromJson(
        _json(
          extra: {
            'kind': 'INQUIRY',
            'announcementId': 'a1',
            'inquiryMessageLimit': 10,
            'inquiryQuotaLifted': true,
          },
        ),
      ).copyWith(hasUnread: true);

      expect(model.bidId, isNull);
      expect(model.announcementId, 'a1');
      expect(model.inquiryMessageLimit, 10);
      expect(model.inquiryQuotaLifted, isTrue);
    });
  });
}
