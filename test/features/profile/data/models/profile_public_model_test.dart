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
        'gpPro': false,
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

  group('ProfilePublicModel.reliabilityPercent (FLUTTER-NV)', () {
    test('lu tel quel, borné à 0..100', () {
      expect(
        ProfilePublicModel.fromJson({
          'userId': 'u1',
          'reliabilityPercent': 96,
        }).reliabilityPercent,
        96,
      );
      expect(
        ProfilePublicModel.fromJson({
          'userId': 'u1',
          'reliabilityPercent': 120,
        }).reliabilityPercent,
        100,
      );
    });

    test('absent (moins de 3 envois, back antérieur) → null', () {
      expect(
        ProfilePublicModel.fromJson({'userId': 'u1'}).reliabilityPercent,
        isNull,
      );
    });
  });

  group('ProfilePublicModel.senderIncidentCount (FLUTTER-E0/E6)', () {
    test('lu, 0 quand absent (back antérieur)', () {
      expect(
        ProfilePublicModel.fromJson({
          'userId': 'u1',
          'senderIncidentCount': 4,
        }).senderIncidentCount,
        4,
      );
      expect(
        ProfilePublicModel.fromJson({'userId': 'u1'}).senderIncidentCount,
        0,
      );
    });
  });
}
