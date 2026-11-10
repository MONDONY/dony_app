import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
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

  group('ProfilePublicModel : taux de fiabilité retiré', () {
    test('ignores_legacy_reliability_percent_in_json', () {
      final model = ProfilePublicModel.fromJson({
        'userId': 'u1',
        'displayName': 'Fatou',
        'reliabilityPercent': 96,
      });
      expect(model.userId, 'u1');
      expect(model.displayName, 'Fatou');
    });
  });

  group('ProfilePublicModel : incidents expéditeur retirés', () {
    test('ignores_legacy_sender_incident_count_in_json', () {
      final model = ProfilePublicModel.fromJson({
        'userId': 'u1',
        'senderIncidentCount': 4,
      });
      expect(model.userId, 'u1');
    });
  });

  group('ProfilePublicModel : statut légal du voyageur (lot 2)', () {
    test('ancien back : champs absents donnent null', () {
      final m = ProfilePublicModel.fromJson({'userId': 'u1'});
      expect(m.travelerStatus, isNull);
      expect(m.businessName, isNull);
      expect(m.businessRegistrationNumber, isNull);
      expect(m.businessCountry, isNull);
    });

    test('professionnel lu', () {
      final m = ProfilePublicModel.fromJson({
        'userId': 'u1',
        'travelerStatus': 'PROFESSIONAL',
        'businessName': 'Diallo Express SARL',
        'businessRegistrationNumber': 'CI-ABJ-2021-B-12345',
        'businessCountry': 'CI',
      });
      expect(m.travelerStatus, TravelerStatus.professional);
      expect(m.businessName, 'Diallo Express SARL');
      expect(m.businessRegistrationNumber, 'CI-ABJ-2021-B-12345');
      expect(m.businessCountry, 'CI');
    });

    test('particulier lu, statut inconnu : null', () {
      expect(
        ProfilePublicModel.fromJson({
          'userId': 'u1',
          'travelerStatus': 'INDIVIDUAL',
        }).travelerStatus,
        TravelerStatus.individual,
      );
      expect(
        ProfilePublicModel.fromJson({
          'userId': 'u1',
          'travelerStatus': 'X',
        }).travelerStatus,
        isNull,
      );
    });
  });
}
