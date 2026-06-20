import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MatchingRequestModel.fromJson parses full DTO', () {
    final json = <String, dynamic>{
      'id': 'r1',
      'tripId': 't1',
      'tripCorridor': 'Paris → Bamako',
      'tripDepartureDate': '2026-07-10',
      'tripAvailableKg': 12.0,
      'senderId': 's1',
      'senderName': 'Awa Diallo',
      'senderInitials': 'AD',
      'senderRating': 4.8,
      'senderTotalSent': 7,
      'weightKg': 3.0,
      'contentType': 'Documents',
      'budgetPerKg': 9.5,
      'packagePhotoUrl': 'https://x/p.jpg',
      'messageExcerpt': 'Colis urgent',
      'matchScore': 92,
      'requestedAt': '2026-06-19T08:30:00',
    };
    final m = MatchingRequestModel.fromJson(json);
    expect(m.id, 'r1');
    expect(m.tripId, 't1');
    expect(m.tripCorridor, 'Paris → Bamako');
    expect(m.tripDepartureDate, DateTime(2026, 7, 10));
    expect(m.tripAvailableKg, 12.0);
    expect(m.senderName, 'Awa Diallo');
    expect(m.senderInitials, 'AD');
    expect(m.senderRating, 4.8);
    expect(m.senderTotalSent, 7);
    expect(m.weightKg, 3.0);
    expect(m.contentType, 'Documents');
    expect(m.budgetPerKg, 9.5);
    expect(m.packagePhotoUrl, 'https://x/p.jpg');
    expect(m.messageExcerpt, 'Colis urgent');
    expect(m.matchScore, 92);
    expect(m.requestedAt, DateTime(2026, 6, 19, 8, 30));
  });

  test('tolerates null optionals', () {
    final json = <String, dynamic>{
      'id': 'r2',
      'tripId': 't2',
      'tripCorridor': 'Lyon → Dakar',
      'tripDepartureDate': '2026-08-01',
      'tripAvailableKg': 5.0,
      'senderId': 's2',
      'senderName': 'Moussa',
      'senderInitials': 'M',
      'senderRating': 0.0,
      'senderTotalSent': 0,
      'weightKg': 1.5,
      'matchScore': 40,
      'requestedAt': '2026-06-19T08:30:00',
    };
    final m = MatchingRequestModel.fromJson(json);
    expect(m.contentType, isNull);
    expect(m.budgetPerKg, isNull);
    expect(m.packagePhotoUrl, isNull);
    expect(m.messageExcerpt, isNull);
  });
}
