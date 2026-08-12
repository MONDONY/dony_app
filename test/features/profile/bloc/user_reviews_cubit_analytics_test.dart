import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/profile/bloc/user_reviews_cubit.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockRatingRepository extends Mock implements RatingRepository {}

// ─── Fixtures ─────────────────────────────────────────────────────────────────

final _kSummary = RatingSummary(
  averageRating: 4.8,
  ratingCount: 12,
  distribution: const {1: 0, 2: 0, 3: 0, 4: 2, 5: 10},
  ratings: [],
  page: 0,
  totalPages: 1,
);

void main() {
  late _MockRatingRepository repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockRatingRepository();
    backend = MockAnalyticsBackend();
  });

  UserReviewsCubit makeCubit({bool analyticsEnabled = true}) {
    final analytics = analyticsEnabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return UserReviewsCubit(repo, analytics);
  }

  group('public_reviews_opened', () {
    test('fires once when seeded via initialSummary (seed path)', () async {
      final cubit = makeCubit();
      await cubit.load('user-1', seed: _kSummary);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.publicReviewsOpened, {
          'rating_count': 12,
        }),
      ).called(1);
    });

    test('fires once when loaded from network (no seed)', () async {
      when(
        () => repo.getUserRatings(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => _kSummary);

      final cubit = makeCubit();
      await cubit.load('user-1');
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.publicReviewsOpened, {
          'rating_count': 12,
        }),
      ).called(1);
    });

    test('fires only ONCE even when load is called twice', () async {
      when(
        () => repo.getUserRatings(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => _kSummary);

      final cubit = makeCubit();
      await cubit.load('user-1', seed: _kSummary);
      await cubit.load('user-1', seed: _kSummary);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.publicReviewsOpened, any()),
      ).called(1);
    });

    test('does NOT fire when analytics disabled', () async {
      final cubit = makeCubit(analyticsEnabled: false);
      await cubit.load('user-1', seed: _kSummary);
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => backend.capture(AnalyticsEvents.publicReviewsOpened, any()),
      );
    });

    test('does NOT fire when network load fails', () async {
      when(
        () => repo.getUserRatings(any(), page: any(named: 'page')),
      ).thenThrow(Exception('network error'));

      final cubit = makeCubit();
      await cubit.load('user-1');
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => backend.capture(AnalyticsEvents.publicReviewsOpened, any()),
      );
    });
  });

  group('UserReviewsCubit state transitions', () {
    blocTest<UserReviewsCubit, UserReviewsState>(
      'emits [Loaded] with seeded data',
      build: () => makeCubit(),
      act: (c) => c.load('user-1', seed: _kSummary),
      expect: () => [
        isA<UserReviewsLoaded>().having(
          (s) => s.summary.ratingCount,
          'ratingCount',
          12,
        ),
      ],
    );

    blocTest<UserReviewsCubit, UserReviewsState>(
      'emits [Loading, Loaded] when fetching from network',
      build: () {
        when(
          () => repo.getUserRatings(any(), page: any(named: 'page')),
        ).thenAnswer((_) async => _kSummary);
        return makeCubit();
      },
      act: (c) => c.load('user-1'),
      expect: () => [isA<UserReviewsLoading>(), isA<UserReviewsLoaded>()],
    );

    blocTest<UserReviewsCubit, UserReviewsState>(
      'emits [Loading, Error] on network failure',
      build: () {
        when(
          () => repo.getUserRatings(any(), page: any(named: 'page')),
        ).thenThrow(Exception('network error'));
        return makeCubit();
      },
      act: (c) => c.load('user-1'),
      expect: () => [isA<UserReviewsLoading>(), isA<UserReviewsError>()],
    );
  });
}
