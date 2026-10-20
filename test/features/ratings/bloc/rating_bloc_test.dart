import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart' show ServerException;
import 'package:dony/core/services/store_review_service.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/models/pending_rating.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_prompt_tracker.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class _MockPromptTracker extends Mock implements RatingPromptTracker {}

class _MockStoreReview extends Mock implements StoreReviewService {}

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

    group('avec mémoire des colis déjà proposés (FLUTTER-P2)', () {
      late _MockPromptTracker tracker;

      setUp(() {
        tracker = _MockPromptTracker();
        when(() => mockRepo.getPendingRating()).thenAnswer(
          (_) async => PendingRating(
            bidId: 'bid-42',
            otherPartyName: 'Moussa D.',
            otherPartyId: 'user-99',
            deliveredAt: DateTime(2026, 5, 8),
            isTravelerRating: false,
          ),
        );
      });

      RatingBloc buildWithTracker() => RatingBloc(
        mockRepo,
        makeDisabledAnalytics(backend),
        promptTracker: tracker,
      );

      blocTest<RatingBloc, RatingState>(
        'première fois pour ce colis : la feuille est proposée',
        setUp: () =>
            when(() => tracker.claim('bid-42')).thenAnswer((_) async => true),
        build: buildWithTracker,
        act: (bloc) => bloc.add(const PendingRatingChecked()),
        expect: () => [
          isA<PendingRatingFound>().having((s) => s.bidId, 'bidId', 'bid-42'),
        ],
        verify: (_) => verify(() => tracker.claim('bid-42')).called(1),
      );

      blocTest<RatingBloc, RatingState>(
        'colis déjà proposé : plus d\'ouverture automatique',
        setUp: () =>
            when(() => tracker.claim('bid-42')).thenAnswer((_) async => false),
        build: buildWithTracker,
        act: (bloc) => bloc.add(const PendingRatingChecked()),
        expect: () => [isA<PendingRatingNone>()],
      );

      blocTest<RatingBloc, RatingState>(
        'aucune note en attente : la mémoire n\'est pas touchée',
        setUp: () => when(
          () => mockRepo.getPendingRating(),
        ).thenAnswer((_) async => null),
        build: buildWithTracker,
        act: (bloc) => bloc.add(const PendingRatingChecked()),
        expect: () => [isA<PendingRatingNone>()],
        verify: (_) => verifyNever(() => tracker.claim(any())),
      );
    });

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

  group('avis Store après une note', () {
    late _MockStoreReview storeReview;

    setUp(() {
      storeReview = _MockStoreReview();
      when(
        () => storeReview.requestAfterRating(
          stars: any(named: 'stars'),
          roleRated: any(named: 'roleRated'),
        ),
      ).thenAnswer((_) async => true);
    });

    RatingBloc buildWithReview() => RatingBloc(
      mockRepo,
      makeDisabledAnalytics(backend),
      storeReview: storeReview,
    );

    blocTest<RatingBloc, RatingState>(
      'note du voyageur envoyée : propose l\'avis Store avec la note',
      setUp: () {
        when(
          () => mockRepo.submitRating(bidId: 'bid-1', stars: 5),
        ).thenAnswer((_) async {});
      },
      build: buildWithReview,
      act: (bloc) =>
          bloc.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 5)),
      expect: () => [isA<RatingLoading>(), isA<RatingSuccess>()],
      verify: (_) => verify(
        () => storeReview.requestAfterRating(stars: 5, roleRated: 'traveler'),
      ).called(1),
    );

    blocTest<RatingBloc, RatingState>(
      'note de l\'expéditeur envoyée : propose l\'avis Store avec la note',
      setUp: () {
        when(
          () => mockRepo.submitTravelerRating(bidId: 'bid-1', stars: 4),
        ).thenAnswer((_) async {});
      },
      build: buildWithReview,
      act: (bloc) => bloc.add(
        const TravelerRatingSubmitRequested(bidId: 'bid-1', stars: 4),
      ),
      expect: () => [isA<RatingLoading>(), isA<RatingSuccess>()],
      verify: (_) => verify(
        () => storeReview.requestAfterRating(stars: 4, roleRated: 'sender'),
      ).called(1),
    );

    blocTest<RatingBloc, RatingState>(
      'note refusée par le serveur : aucun avis Store proposé',
      setUp: () {
        when(
          () => mockRepo.submitRating(bidId: 'bid-1', stars: 5),
        ).thenThrow(const ServerException('Bid non trouvé'));
      },
      build: buildWithReview,
      act: (bloc) =>
          bloc.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 5)),
      expect: () => [isA<RatingLoading>(), isA<RatingError>()],
      verify: (_) => verifyNever(
        () => storeReview.requestAfterRating(
          stars: any(named: 'stars'),
          roleRated: any(named: 'roleRated'),
        ),
      ),
    );
  });
}
