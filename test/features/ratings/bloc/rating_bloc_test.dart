import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart' show AppException, ServerException;
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

void main() {
  late MockRatingRepository mockRepo;

  setUp(() {
    mockRepo = MockRatingRepository();
  });

  RatingBloc buildBloc() => RatingBloc(mockRepo);

  group('RatingSubmitRequested', () {
    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingSuccess] when submission succeeds',
      setUp: () {
        when(() => mockRepo.submitRating(
              bidId: 'bid-1',
              stars: 5,
              comment: 'Super voyageur !',
            )).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const RatingSubmitRequested(
        bidId: 'bid-1',
        stars: 5,
        comment: 'Super voyageur !',
      )),
      expect: () => [
        isA<RatingLoading>(),
        isA<RatingSuccess>(),
      ],
    );

    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingSuccess] without comment',
      setUp: () {
        when(() => mockRepo.submitRating(
              bidId: 'bid-1',
              stars: 4,
              comment: null,
            )).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const RatingSubmitRequested(
        bidId: 'bid-1',
        stars: 4,
      )),
      expect: () => [
        isA<RatingLoading>(),
        isA<RatingSuccess>(),
      ],
    );

    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingError] with AppException message',
      setUp: () {
        when(() => mockRepo.submitRating(
              bidId: 'bid-1',
              stars: 3,
              comment: null,
            )).thenThrow(const ServerException('Bid non trouvé'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const RatingSubmitRequested(
        bidId: 'bid-1',
        stars: 3,
      )),
      expect: () => [
        isA<RatingLoading>(),
        isA<RatingError>().having((e) => e.message, 'message', 'Bid non trouvé'),
      ],
    );

    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingError] with fallback message on DioException',
      setUp: () {
        final dioErr = DioException(
          requestOptions: RequestOptions(),
          error: Exception('network error'),
        );
        when(() => mockRepo.submitRating(
              bidId: 'bid-1',
              stars: 2,
              comment: null,
            )).thenThrow(dioErr);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const RatingSubmitRequested(
        bidId: 'bid-1',
        stars: 2,
      )),
      expect: () => [
        isA<RatingLoading>(),
        isA<RatingError>().having(
          (e) => e.message,
          'message',
          contains('Impossible d\'envoyer'),
        ),
      ],
    );

    blocTest<RatingBloc, RatingState>(
      'emits [RatingLoading, RatingError] with fallback message on generic error',
      setUp: () {
        when(() => mockRepo.submitRating(
              bidId: 'bid-1',
              stars: 1,
              comment: null,
            )).thenThrow(Exception('unknown'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const RatingSubmitRequested(
        bidId: 'bid-1',
        stars: 1,
      )),
      expect: () => [
        isA<RatingLoading>(),
        isA<RatingError>().having(
          (e) => e.message,
          'message',
          contains('Impossible d\'envoyer'),
        ),
      ],
    );
  });
}
