import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_dio.dart';

const _summaryJson = {
  'averageRating': 4.5,
  'ratingCount': 2,
  'distribution': {'5': 1, '4': 1},
  'ratings': [
    {
      'stars': 5,
      'comment': 'Parfait',
      'createdAt': '2026-03-01T12:00:00Z',
      'excluded': true,
      'authorName': 'Awa',
      'authorAvatarUrl': 'https://img/a.jpg',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
    },
    {'stars': 4, 'createdAt': '2026-03-02T12:00:00Z'},
  ],
  'page': 1,
  'totalPages': 3,
};

void main() {
  late RecordingApi api;
  late RatingRepository repo;

  setUp(() {
    api = RecordingApi();
    repo = RatingRepository(api.client);
  });

  group('RatingSummary.fromJson', () {
    test('lit la moyenne, la distribution complète et les avis', () {
      final s = RatingSummary.fromJson(_summaryJson);
      expect(s.averageRating, 4.5);
      expect(s.ratingCount, 2);
      expect(s.distribution, {1: 0, 2: 0, 3: 0, 4: 1, 5: 1});
      expect(s.page, 1);
      expect(s.totalPages, 3);
      final first = s.ratings.first;
      expect(first.stars, 5);
      expect(first.comment, 'Parfait');
      expect(first.excluded, isTrue);
      expect(first.authorName, 'Awa');
      expect(first.authorAvatarUrl, 'https://img/a.jpg');
      expect(first.departureCity, 'Paris');
      expect(first.arrivalCity, 'Dakar');
      expect(first.createdAt, DateTime.utc(2026, 3, 1, 12));
      final second = s.ratings.last;
      expect(second.excluded, isFalse);
      expect(second.comment, isNull);
    });

    test('valeurs par défaut sur un corps vide', () {
      final s = RatingSummary.fromJson(const {});
      expect(s.averageRating, 0.0);
      expect(s.ratingCount, 0);
      expect(s.distribution.values, everyElement(0));
      expect(s.distribution.keys, [1, 2, 3, 4, 5]);
      expect(s.ratings, isEmpty);
      expect(s.page, 0);
      expect(s.totalPages, 0);
    });
  });

  group('submitRating', () {
    test('poste la note et le commentaire', () async {
      await repo.submitRating(bidId: 'b1', stars: 5, comment: 'Top');
      expect(api.last.method, 'POST');
      expect(api.last.path, '/ratings');
      expect(api.last.data, {'bidId': 'b1', 'stars': 5, 'comment': 'Top'});
    });

    test('omet un commentaire vide ou nul', () async {
      await repo.submitRating(bidId: 'b1', stars: 3, comment: '');
      expect(api.last.data, {'bidId': 'b1', 'stars': 3});
      await repo.submitRating(bidId: 'b1', stars: 3);
      expect(api.last.data, {'bidId': 'b1', 'stars': 3});
    });
  });

  group('submitTravelerRating', () {
    test('poste sur /ratings/traveler-to-sender', () async {
      await repo.submitTravelerRating(bidId: 'b2', stars: 4, comment: 'Ok');
      expect(api.last.path, '/ratings/traveler-to-sender');
      expect(api.last.data, {'bidId': 'b2', 'stars': 4, 'comment': 'Ok'});
    });

    test('omet le commentaire vide', () async {
      await repo.submitTravelerRating(bidId: 'b2', stars: 2, comment: '');
      expect(api.last.data, {'bidId': 'b2', 'stars': 2});
    });
  });

  test('getUserRatings envoie la page et la taille', () async {
    api.on('GET', '/ratings/user/u1', _summaryJson);
    final s = await repo.getUserRatings('u1', page: 2);
    expect(s.ratingCount, 2);
    expect(api.last.queryParameters, {'page': 2, 'size': 20});
  });

  test('findMineReceived lit /ratings/me/received page 0 par défaut', () async {
    api.on('GET', '/ratings/me/received', _summaryJson);
    final s = await repo.findMineReceived();
    expect(s.ratings, hasLength(2));
    expect(api.last.queryParameters, {'page': 0, 'size': 20});
  });

  group('getPendingRating', () {
    test('rend null sur un 204', () async {
      api.on('GET', '/ratings/pending', null, status: 204);
      expect(await repo.getPendingRating(), isNull);
    });

    test('lit la notation en attente', () async {
      api.on('GET', '/ratings/pending', {
        'bidId': 'b1',
        'otherPartyName': 'Moussa',
        'otherPartyId': 'u2',
        'deliveredAt': '2026-04-01T08:00:00Z',
        'isTravelerRating': true,
      });
      final p = await repo.getPendingRating();
      expect(p, isNotNull);
      expect(p!.bidId, 'b1');
      expect(p.otherPartyName, 'Moussa');
      expect(p.otherPartyId, 'u2');
      expect(p.isTravelerRating, isTrue);
      expect(p.deliveredAt, DateTime.utc(2026, 4, 1, 8));
    });
  });
}
