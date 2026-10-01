import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfilePublicModel', () {
    test('ProfilePublicModel parse bio/languages/transportMode', () {
      final m = ProfilePublicModel.fromJson({
        'userId': 'u1',
        'displayName': 'A',
        'kycVerified': true,
        'isProAccount': false,
        'isKiloPro': false,
        'completedBidsCount': 0,
        'averageRating': 0.0,
        'ratingCount': 0,
        'memberSince': '2024',
        'badges': [],
        'bio': 'Hi',
        'languages': ['FR'],
      });
      expect(m.bio, 'Hi');
      expect(m.languages, ['FR']);
    });

    test('temps de réponse et dernière connexion lus, absents = nuls', () {
      final full = ProfilePublicModel.fromJson({
        'userId': 'u1',
        'measuredResponseMinutes': 42,
        'lastSeenDaysAgo': 3,
      });
      expect(full.measuredResponseMinutes, 42);
      expect(full.lastSeenDaysAgo, 3);

      final old = ProfilePublicModel.fromJson({'userId': 'u1'});
      expect(old.measuredResponseMinutes, isNull);
      expect(old.lastSeenDaysAgo, isNull);
    });
  });
}
