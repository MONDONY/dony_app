import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/bloc/my_reviews_event.dart';
import 'package:dony/features/ratings/bloc/my_reviews_state.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

final _d = DateTime.utc(2026, 6, 1);

final _summaryWithRatings = RatingSummary(
  averageRating: 4.0,
  ratingCount: 3,
  distribution: const {1: 0, 2: 0, 3: 1, 4: 0, 5: 2},
  ratings: [
    RatingItem(stars: 5, createdAt: _d, excluded: false),
    RatingItem(stars: 5, createdAt: _d, excluded: false),
    RatingItem(stars: 3, createdAt: _d, excluded: false),
  ],
  page: 0,
  totalPages: 1,
);

void main() {
  late MockRatingRepository mockRepo;
  late _MockAnalyticsService analytics;

  setUp(() {
    mockRepo = MockRatingRepository();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  MyReviewsBloc buildBloc() => MyReviewsBloc(mockRepo, analytics);

  // 1. État initial
  test('initial state is MyReviewsInitial', () {
    expect(buildBloc().state, isA<MyReviewsInitial>());
  });

  // 2. MyReviewsRequested → [MyReviewsLoading, MyReviewsLoaded]
  blocTest<MyReviewsBloc, MyReviewsState>(
    'emits [MyReviewsLoading, MyReviewsLoaded] on success',
    setUp: () {
      when(() => mockRepo.findMineReceived(page: 0)).thenAnswer(
        (_) async => const RatingSummary(
          averageRating: 4.5,
          ratingCount: 8,
          distribution: {1: 0, 2: 0, 3: 1, 4: 3, 5: 4},
          ratings: [],
          page: 0,
          totalPages: 1,
        ),
      );
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const MyReviewsRequested()),
    expect: () => [isA<MyReviewsLoading>(), isA<MyReviewsLoaded>()],
  );

  // 3. MyReviewsRequested → [MyReviewsLoading, MyReviewsError] si exception
  blocTest<MyReviewsBloc, MyReviewsState>(
    'emits [MyReviewsLoading, MyReviewsError] on failure',
    setUp: () {
      when(
        () => mockRepo.findMineReceived(page: 0),
      ).thenThrow(Exception('Erreur réseau'));
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const MyReviewsRequested()),
    expect: () => [isA<MyReviewsLoading>(), isA<MyReviewsError>()],
  );

  // 4. MyReviewsLoaded contient le bon summary
  blocTest<MyReviewsBloc, MyReviewsState>(
    'MyReviewsLoaded contains correct summary data',
    setUp: () {
      when(() => mockRepo.findMineReceived(page: 0)).thenAnswer(
        (_) async => const RatingSummary(
          averageRating: 4.7,
          ratingCount: 12,
          distribution: {1: 0, 2: 0, 3: 1, 4: 4, 5: 7},
          ratings: [],
          page: 0,
          totalPages: 1,
        ),
      );
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const MyReviewsRequested()),
    expect: () => [
      isA<MyReviewsLoading>(),
      isA<MyReviewsLoaded>()
          .having((s) => s.summary.averageRating, 'averageRating', 4.7)
          .having((s) => s.summary.ratingCount, 'ratingCount', 12),
    ],
  );

  // 5. Succès avec ratingCount == 0
  blocTest<MyReviewsBloc, MyReviewsState>(
    'emits MyReviewsLoaded with ratingCount 0 when no reviews',
    setUp: () {
      when(() => mockRepo.findMineReceived(page: 0)).thenAnswer(
        (_) async => const RatingSummary(
          averageRating: 0.0,
          ratingCount: 0,
          distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
          ratings: [],
          page: 0,
          totalPages: 0,
        ),
      );
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const MyReviewsRequested()),
    expect: () => [
      isA<MyReviewsLoading>(),
      isA<MyReviewsLoaded>().having(
        (s) => s.summary.ratingCount,
        'ratingCount',
        0,
      ),
    ],
  );

  // 6. Filtre étoile : applique la note, ne garde que les avis correspondants
  blocTest<MyReviewsBloc, MyReviewsState>(
    'star filter keeps only ratings of selected stars',
    setUp: () {
      when(
        () => mockRepo.findMineReceived(),
      ).thenAnswer((_) async => _summaryWithRatings);
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const MyReviewsRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const MyReviewsStarFilterToggled(5));
    },
    expect: () => [
      isA<MyReviewsLoading>(),
      isA<MyReviewsLoaded>().having(
        (s) => s.selectedStars,
        'selectedStars',
        null,
      ),
      isA<MyReviewsLoaded>()
          .having((s) => s.selectedStars, 'selectedStars', 5)
          .having((s) => s.visibleRatings.length, 'visible', 2),
    ],
    verify: (_) {
      verify(
        () => analytics.logEvent('reviews_filtered', properties: {'stars': 5}),
      ).called(1);
    },
  );

  // 7. Re-tap sur la même note → filtre annulé (toutes les notes)
  blocTest<MyReviewsBloc, MyReviewsState>(
    're-tapping the active star clears the filter',
    setUp: () {
      when(
        () => mockRepo.findMineReceived(),
      ).thenAnswer((_) async => _summaryWithRatings);
    },
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const MyReviewsRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const MyReviewsStarFilterToggled(5));
      bloc.add(const MyReviewsStarFilterToggled(5));
    },
    expect: () => [
      isA<MyReviewsLoading>(),
      isA<MyReviewsLoaded>().having(
        (s) => s.selectedStars,
        'selectedStars',
        null,
      ),
      isA<MyReviewsLoaded>().having((s) => s.selectedStars, 'selectedStars', 5),
      isA<MyReviewsLoaded>()
          .having((s) => s.selectedStars, 'selectedStars', null)
          .having((s) => s.visibleRatings.length, 'visible', 3),
    ],
  );
}
