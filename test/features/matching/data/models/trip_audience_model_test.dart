import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson lit les deux compteurs', () {
    final model = TripAudienceModel.fromJson(const {
      'uniqueViewerCount': 3,
      'shareViewCount': 41,
    });

    expect(model.uniqueViewerCount, 3);
    expect(model.shareViewCount, 41);
    expect(model.isEmpty, isFalse);
  });

  test('fromJson tolère des champs absents : zéro partout, audience vide', () {
    final model = TripAudienceModel.fromJson(const {});

    expect(model.uniqueViewerCount, 0);
    expect(model.shareViewCount, 0);
    expect(model.isEmpty, isTrue);
  });
}
