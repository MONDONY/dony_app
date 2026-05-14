import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/ratings/bloc/my_reviews_bloc.dart';
import 'package:dony/features/ratings/bloc/my_reviews_event.dart';
import 'package:dony/features/ratings/bloc/my_reviews_state.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}


void main() {
  late MockRatingRepository mockRepo;

  setUp(() {
    mockRepo = MockRatingRepository();
  });

  MyReviewsBloc buildBloc() => MyReviewsBloc(mockRepo);

  // 1. État initial
  test('initial state is MyReviewsInitial', () {
    expect(buildBloc().state, isA<MyReviewsInitial>());
  });

  // 2. MyReviewsRequested → [MyReviewsLoading, MyReviewsLoaded]
  blocTest<MyReviewsBloc, MyReviewsState>(
    'emits [MyReviewsLoading, MyReviewsLoaded] on success',
    setUp: () {
      when(() => mockRepo.findMineReceived(page: 0))
          .thenAnswer((_) async => const RatingSummary(
                averageRating: 4.5,
                ratingCount: 8,
                distribution: {1: 0, 2: 0, 3: 1, 4: 3, 5: 4},
                ratings: [],
                page: 0,
                totalPages: 1,
              ));
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const MyReviewsRequested()),
    expect: () => [
      isA<MyReviewsLoading>(),
      isA<MyReviewsLoaded>(),
    ],
  );

  // 3. MyReviewsRequested → [MyReviewsLoading, MyReviewsError] si exception
  blocTest<MyReviewsBloc, MyReviewsState>(
    'emits [MyReviewsLoading, MyReviewsError] on failure',
    setUp: () {
      when(() => mockRepo.findMineReceived(page: 0))
          .thenThrow(Exception('Erreur réseau'));
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const MyReviewsRequested()),
    expect: () => [
      isA<MyReviewsLoading>(),
      isA<MyReviewsError>(),
    ],
  );

  // 4. MyReviewsLoaded contient le bon summary
  blocTest<MyReviewsBloc, MyReviewsState>(
    'MyReviewsLoaded contains correct summary data',
    setUp: () {
      when(() => mockRepo.findMineReceived(page: 0))
          .thenAnswer((_) async => const RatingSummary(
                averageRating: 4.7,
                ratingCount: 12,
                distribution: {1: 0, 2: 0, 3: 1, 4: 4, 5: 7},
                ratings: [],
                page: 0,
                totalPages: 1,
              ));
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
      when(() => mockRepo.findMineReceived(page: 0))
          .thenAnswer((_) async => const RatingSummary(
                averageRating: 0.0,
                ratingCount: 0,
                distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
                ratings: [],
                page: 0,
                totalPages: 0,
              ));
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const MyReviewsRequested()),
    expect: () => [
      isA<MyReviewsLoading>(),
      isA<MyReviewsLoaded>()
          .having((s) => s.summary.ratingCount, 'ratingCount', 0),
    ],
  );
}
