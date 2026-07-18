import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RematchSuggestionModel.fromJson', () {
    final baseJson = <String, dynamic>{
      'suggestionId': 'sug-1',
      'announcementId': 'ann-2',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'departureDate': '2024-02-01T00:00:00.000',
      'availableKg': 5.0,
      'pricePerKg': 12.0,
    };

    test('parses traveler enrichment fields when present', () {
      final json = {
        ...baseJson,
        'travelerFirstName': 'Awa',
        'travelerRating': 4.8,
        'travelerRatingCount': 23,
      };

      final model = RematchSuggestionModel.fromJson(json);

      expect(model.suggestionId, 'sug-1');
      expect(model.travelerFirstName, 'Awa');
      expect(model.travelerRating, 4.8);
      expect(model.travelerRatingCount, 23);
    });

    test('travelerRating tolerates an integer JSON value (num→double)', () {
      final json = {
        ...baseJson,
        'travelerFirstName': 'Moussa',
        'travelerRating': 5,
        'travelerRatingCount': 1,
      };

      final model = RematchSuggestionModel.fromJson(json);

      expect(model.travelerRating, 5.0);
    });

    test('leaves traveler enrichment fields null when absent (back not yet deployed)', () {
      final model = RematchSuggestionModel.fromJson(baseJson);

      expect(model.travelerFirstName, isNull);
      expect(model.travelerRating, isNull);
      expect(model.travelerRatingCount, isNull);
      // Existing fields still parse correctly.
      expect(model.departureCity, 'Paris');
      expect(model.availableKg, 5.0);
    });
  });

  group('CancellationModel.fromJson', () {
    test('parses nested rematchSuggestions with enrichment fields', () {
      final json = {
        'announcementId': 'ann-1',
        'affectedBidsCount': 2,
        'reason': 'TRAVELER_SICK',
        'cancelledAt': '2024-01-15T00:00:00.000',
        'rematchSuggestions': [
          {
            'suggestionId': 'sug-1',
            'announcementId': 'ann-2',
            'departureCity': 'Paris',
            'arrivalCity': 'Dakar',
            'departureDate': '2024-02-01T00:00:00.000',
            'availableKg': 5.0,
            'pricePerKg': 12.0,
            'travelerFirstName': 'Awa',
            'travelerRating': 4.8,
            'travelerRatingCount': 23,
          },
        ],
      };

      final model = CancellationModel.fromJson(json);

      expect(model.rematchSuggestions, hasLength(1));
      expect(model.rematchSuggestions.single.travelerFirstName, 'Awa');
    });
  });
}
