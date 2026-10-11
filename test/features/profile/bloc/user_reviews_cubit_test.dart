import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/bloc/user_reviews_cubit.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRatingRepository extends Mock implements RatingRepository {}

RatingItem _rating(int stars) => RatingItem(
  stars: stars,
  createdAt: DateTime(2026, 5, stars),
  excluded: false,
);

RatingSummary _summary({
  required int page,
  int totalPages = 3,
  List<RatingItem> ratings = const [],
}) => RatingSummary(
  averageRating: 4.5,
  ratingCount: 30,
  distribution: const {5: 30},
  ratings: ratings,
  page: page,
  totalPages: totalPages,
);

void main() {
  late _MockRatingRepository repo;

  setUp(() => repo = _MockRatingRepository());

  UserReviewsCubit build() =>
      UserReviewsCubit(repo, makeDisabledAnalytics(MockAnalyticsBackend()));

  TypeMatcher<UserReviewsLoaded> loaded({
    required int count,
    required bool loadingMore,
  }) => isA<UserReviewsLoaded>()
      .having((s) => s.allRatings.length, 'allRatings.length', count)
      .having((s) => s.isLoadingMore, 'isLoadingMore', loadingMore);

  blocTest<UserReviewsCubit, UserReviewsState>(
    'chargement en échec → Loading puis Error avec l’exception déballée',
    build: () {
      when(
        () => repo.getUserRatings(any(), page: any(named: 'page')),
      ).thenThrow(const ServerException());
      return build();
    },
    act: (c) => c.load('u-1'),
    expect: () => [
      isA<UserReviewsLoading>(),
      isA<UserReviewsError>().having(
        (s) => s.error,
        'error',
        isA<ServerException>(),
      ),
    ],
  );

  group('loadNextPage', () {
    blocTest<UserReviewsCubit, UserReviewsState>(
      'ajoute la page suivante aux avis déjà chargés',
      build: () {
        when(() => repo.getUserRatings('u-1', page: 1)).thenAnswer(
          (_) async => _summary(page: 1, ratings: [_rating(4), _rating(5)]),
        );
        return build();
      },
      seed: () => UserReviewsLoaded(
        summary: _summary(page: 0, ratings: [_rating(3)]),
        allRatings: [_rating(3)],
      ),
      act: (c) => c.loadNextPage('u-1'),
      expect: () => [
        loaded(count: 1, loadingMore: true),
        loaded(
          count: 3,
          loadingMore: false,
        ).having((s) => s.summary.page, 'summary.page', 1),
      ],
    );

    blocTest<UserReviewsCubit, UserReviewsState>(
      'erreur de pagination → spinner masqué, avis conservés',
      build: () {
        when(
          () => repo.getUserRatings(any(), page: any(named: 'page')),
        ).thenThrow(const ServerException());
        return build();
      },
      seed: () => UserReviewsLoaded(
        summary: _summary(page: 0),
        allRatings: [_rating(3)],
      ),
      act: (c) => c.loadNextPage('u-1'),
      expect: () => [
        loaded(count: 1, loadingMore: true),
        loaded(count: 1, loadingMore: false),
      ],
    );

    blocTest<UserReviewsCubit, UserReviewsState>(
      'dernière page atteinte → aucun appel',
      build: build,
      seed: () =>
          UserReviewsLoaded(summary: _summary(page: 2), allRatings: const []),
      act: (c) => c.loadNextPage('u-1'),
      expect: () => <UserReviewsState>[],
      verify: (_) => verifyZeroInteractions(repo),
    );

    blocTest<UserReviewsCubit, UserReviewsState>(
      'pagination déjà en cours → aucun appel',
      build: build,
      seed: () => UserReviewsLoaded(
        summary: _summary(page: 0),
        allRatings: const [],
        isLoadingMore: true,
      ),
      act: (c) => c.loadNextPage('u-1'),
      expect: () => <UserReviewsState>[],
      verify: (_) => verifyZeroInteractions(repo),
    );

    blocTest<UserReviewsCubit, UserReviewsState>(
      'rien de chargé → aucun appel',
      build: build,
      act: (c) => c.loadNextPage('u-1'),
      expect: () => <UserReviewsState>[],
      verify: (_) => verifyZeroInteractions(repo),
    );
  });
}
