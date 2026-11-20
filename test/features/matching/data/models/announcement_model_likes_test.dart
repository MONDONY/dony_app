import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json([Map<String, dynamic> extra = const {}]) => {
  'id': 'ann1',
  'travelerId': 'traveler1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': '2024-06-01',
  'availableKg': 10.0,
  'totalKg': 20.0,
  'pricePerKg': 15.0,
  'status': 'ACTIVE',
  'createdAt': '2024-01-01T00:00:00Z',
  'updatedAt': '2024-01-01T00:00:00Z',
  ...extra,
};

void main() {
  test('fromJson_lit_likeCount_et_likedByMe', () {
    final a = AnnouncementModel.fromJson(
      _json({'likeCount': 12, 'likedByMe': true}),
    );
    expect(a.likeCount, 12);
    expect(a.likedByMe, isTrue);
  });

  test('fromJson_sans_ces_champs_donne_0_et_false', () {
    final a = AnnouncementModel.fromJson(_json());
    expect(a.likeCount, 0);
    expect(a.likedByMe, isFalse);
  });

  test('fromJson tolère null et nombre décimal', () {
    final a = AnnouncementModel.fromJson(
      _json({'likeCount': null, 'likedByMe': null}),
    );
    expect(a.likeCount, 0);
    expect(a.likedByMe, isFalse);
    expect(AnnouncementModel.fromJson(_json({'likeCount': 3.0})).likeCount, 3);
  });

  test('aller-retour JSON', () {
    final a = AnnouncementModel.fromJson(
      _json({'likeCount': 7, 'likedByMe': true}),
    );
    final b = AnnouncementModel.fromJson(a.toJson());
    expect(b.likeCount, 7);
    expect(b.likedByMe, isTrue);
  });
}
