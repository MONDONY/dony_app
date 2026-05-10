import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NegotiationThread.fromJson parses with messages', () {
    final json = {
      'id': 't-1',
      'packageRequestId': 'pr-1',
      'travelerId': 'tr-1',
      'travelerAnnouncementId': null,
      'travelerTravelDate': '2026-06-15',
      'travelerAvailableKg': 10.0,
      'status': 'OPEN',
      'currentPriceEur': 30.0,
      'roundsCount': 1,
      'lastActivityAt': '2026-05-10T10:00:00Z',
      'createdAt': '2026-05-10T10:00:00Z',
      'messages': [
        {
          'id': 'm-1', 'threadId': 't-1', 'fromUserId': 'tr-1',
          'kind': 'PROPOSAL', 'proposedPriceEur': 30.0, 'body': null,
          'createdAt': '2026-05-10T10:00:00Z',
        }
      ],
      'paymentIntentClientSecret': null,
    };

    final t = NegotiationThread.fromJson(json);

    expect(t.id, 't-1');
    expect(t.status, NegotiationThreadStatus.open);
    expect(t.messages.length, 1);
    expect(t.messages.first.kind, NegotiationMessageKind.proposal);
  });
}
