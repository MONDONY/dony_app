import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart' show ServerException;
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/models/pending_rating.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

void main() {
  late MockRatingRepository mockRepo;
  late MockAnalyticsBackend backend;

  setUp(() {
    mockRepo = MockRatingRepository();
    backend = MockAnalyticsBackend();
  });

  RatingBloc buildBloc() {
    final analytics = makeDisabledAnalytics(backend);
    return RatingBloc(mockRepo, analytics);
  }

  group('RatingSubmitRequested', () {
    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingSuccess] when submission succeeds',
      setUp: () {
        when(
          () => mockRepo.submitRating(
            bidId: 'bid-1',
            stars: 5,
            comment: 'Super voyageur !',
          ),
        ).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const RatingSubmitRequested(
          bidId: 'bid-1',
          stars: 5,
          comment: 'Super voyageur !',
        ),
      ),
      expect: () => [isA<RatingLoading>(), isA<RatingSuccess>()],
    );

    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingSuccess] without comment',
      setUp: () {
        when(
          () => mockRepo.submitRating(bidId: 'bid-1', stars: 4),
        ).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 4)),
      expect: () => [isA<RatingLoading>(), isA<RatingSuccess>()],
    );

    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingError] with AppException message',
      setUp: () {
        when(
          () => mockRepo.submitRating(bidId: 'bid-1', stars: 3),
        ).thenThrow(const ServerException('Bid non trouvé'));
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 3)),
      expect: () => [
        isA<RatingLoading>(),
        isA<RatingError>().having(
          (e) => e.error.message,
          'message',
          'Bid non trouvé',
        ),
      ],
    );

    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingError] with fallback message on DioException',
      setUp: () {
        final dioErr = DioException(
          requestOptions: RequestOptions(),
          error: Exception('network error'),
        );
        when(
          () => mockRepo.submitRating(bidId: 'bid-1', stars: 2),
        ).thenThrow(dioErr);
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 2)),
      expect: () => [isA<RatingLoading>(), isA<RatingError>()],
    );

    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingError] with fallback message on generic error',
      setUp: () {
        when(
          () => mockRepo.submitRating(bidId: 'bid-1', stars: 1),
        ).thenThrow(Exception('unknown'));
      },
      build: buildBloc,
      act: (bloc) =>
          bloc.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 1)),
      expect: () => [isA<RatingLoading>(), isA<RatingError>()],
    );
  });

  group('TravelerRatingSubmitRequested', () {
    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingSuccess] on success',
      setUp: () {
        when(
          () => mockRepo.submitTravelerRating(
            bidId: 'bid-1',
            stars: 4,
            comment: 'Bon expéditeur',
          ),
        ).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const TravelerRatingSubmitRequested(
          bidId: 'bid-1',
          stars: 4,
          comment: 'Bon expéditeur',
        ),
      ),
      expect: () => [isA<RatingLoading>(), isA<RatingSuccess>()],
    );

    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingError] on failure',
      setUp: () {
        when(
          () => mockRepo.submitTravelerRating(bidId: 'bid-1', stars: 3),
        ).thenThrow(const ServerException('Interdit'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const TravelerRatingSubmitRequested(bidId: 'bid-1', stars: 3),
      ),
      expect: () => [
        isA<RatingLoading>(),
        isA<RatingError>().having(
          (e) => e.error.message,
          'message',
          'Interdit',
        ),
      ],
    );
  });

  group('PendingRatingChecked', () {
    blocTest<RatingBloc, RatingState>(
      'emits PendingRatingFound when pending exists',
      setUp: () {
        when(() => mockRepo.getPendingRating()).thenAnswer(
          (_) async => PendingRating(
            bidId: 'bid-42',
            otherPartyName: 'Moussa D.',
            otherPartyId: 'user-99',
            deliveredAt: DateTime(2026, 5, 8),
            isTravelerRating: false,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const PendingRatingChecked()),
      expect: () => [
        isA<PendingRatingFound>()
            .having((s) => s.bidId, 'bidId', 'bid-42')
            .having((s) => s.isTravelerRating, 'isTravelerRating', false),
      ],
    );

    blocTest<RatingBloc, RatingState>(
      'emits PendingRatingNone when no pending',
      setUp: () {
        when(() => mockRepo.getPendingRating()).thenAnswer((_) async => null);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const PendingRatingChecked()),
      expect: () => [isA<PendingRatingNone>()],
    );

    blocTest<RatingBloc, RatingState>(
      'emits PendingRatingNone silently on network error',
      setUp: () {
        when(() => mockRepo.getPendingRating()).thenThrow(Exception('network'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const PendingRatingChecked()),
      expect: () => [isA<PendingRatingNone>()],
    );
  });

  group('UserRatingsLoadRequested', () {
    blocTest<RatingBloc, RatingState>(
      'emits UserRatingsLoaded on success',
      setUp: () {
        when(() => mockRepo.getUserRatings('user-1')).thenAnswer(
          (_) async => const RatingSummary(
            averageRating: 4.5,
            ratingCount: 10,
            distribution: {1: 0, 2: 0, 3: 1, 4: 4, 5: 5},
            ratings: [],
            page: 0,
            totalPages: 1,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const UserRatingsLoadRequested(userId: 'user-1')),
      expect: () => [
        isA<UserRatingsLoaded>()
            .having((s) => s.ratingCount, 'ratingCount', 10)
            .having((s) => s.averageRating, 'averageRating', 4.5),
      ],
    );

    blocTest<RatingBloc, RatingState>(
      'emits RatingError on failure',
      setUp: () {
        when(
          () => mockRepo.getUserRatings('user-1'),
        ).thenThrow(const ServerException('Utilisateur introuvable'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const UserRatingsLoadRequested(userId: 'user-1')),
      expect: () => [
        isA<RatingError>().having(
          (e) => e.error.message,
          'message',
          'Utilisateur introuvable',
        ),
      ],
    );
  });
}
