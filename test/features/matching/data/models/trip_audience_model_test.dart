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

  test('TripAudienceModel_lit_likeCount_et_0_si_absent', () {
    expect(TripAudienceModel.fromJson(const {'likeCount': 5}).likeCount, 5);
    expect(TripAudienceModel.fromJson(const {}).likeCount, 0);
  });

  test('props_incluent_likeCount', () {
    const a = TripAudienceModel(
      uniqueViewerCount: 1,
      shareViewCount: 2,
      likeCount: 3,
    );
    const b = TripAudienceModel(
      uniqueViewerCount: 1,
      shareViewCount: 2,
      likeCount: 4,
    );
    expect(a, isNot(b));
    expect(a.props, contains(3));
  });

  test('isEmpty ignore les j\'aime', () {
    expect(
      const TripAudienceModel(
        uniqueViewerCount: 0,
        shareViewCount: 0,
        likeCount: 9,
      ).isEmpty,
      isTrue,
    );
  });
}
