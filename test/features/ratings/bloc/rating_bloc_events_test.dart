import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/rating_events_service.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRatingRepository extends Mock implements RatingRepository {}

/// FLUTTER-HQ : toute instance de RatingBloc signale la note envoyée (ou déjà
/// présente, 409 `already-rated`) pour que le détail du colis ouvert se relise.
void main() {
  late _MockRatingRepository repo;
  late RatingEventsService events;
  late List<String> rated;

  setUp(() {
    repo = _MockRatingRepository();
    events = RatingEventsService();
    rated = [];
    events.rated.listen(rated.add);
  });

  tearDown(() => events.dispose());

  RatingBloc build() => RatingBloc(
    repo,
    makeDisabledAnalytics(MockAnalyticsBackend()),
    ratingEvents: events,
  );

  group('expéditeur → voyageur', () {
    blocTest<RatingBloc, RatingState>(
      'succès → signal « note envoyée » avec le bid',
      setUp: () => when(
        () => repo.submitRating(bidId: 'bid-1', stars: 5),
      ).thenAnswer((_) async {}),
      build: build,
      act: (b) => b.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 5)),
      expect: () => [isA<RatingLoading>(), isA<RatingSuccess>()],
      verify: (_) => expect(rated, ['bid-1']),
    );

    blocTest<RatingBloc, RatingState>(
      '409 already-rated → erreur affichée ET signal (le colis se relit)',
      setUp: () => when(
        () => repo.submitRating(bidId: 'bid-1', stars: 4),
      ).thenThrow(const ConflictException('Conflict', code: 'already-rated')),
      build: build,
      act: (b) => b.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 4)),
      expect: () => [
        isA<RatingLoading>(),
        isA<RatingError>().having((s) => s.error.code, 'code', 'already-rated'),
      ],
      verify: (_) => expect(rated, ['bid-1']),
    );

    blocTest<RatingBloc, RatingState>(
      'autre erreur → aucun signal',
      setUp: () => when(
        () => repo.submitRating(bidId: 'bid-1', stars: 4),
      ).thenThrow(const ServerException('boom')),
      build: build,
      act: (b) => b.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 4)),
      expect: () => [isA<RatingLoading>(), isA<RatingError>()],
      verify: (_) => expect(rated, isEmpty),
    );

    blocTest<RatingBloc, RatingState>(
      'autre conflit (409 sans already-rated) → aucun signal',
      setUp: () => when(
        () => repo.submitRating(bidId: 'bid-1', stars: 4),
      ).thenThrow(const ConflictException('Conflict', code: 'other')),
      build: build,
      act: (b) => b.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 4)),
      expect: () => [isA<RatingLoading>(), isA<RatingError>()],
      verify: (_) => expect(rated, isEmpty),
    );
  });

  group('voyageur → expéditeur', () {
    blocTest<RatingBloc, RatingState>(
      'succès → signal « note envoyée » avec le bid',
      setUp: () => when(
        () => repo.submitTravelerRating(bidId: 'bid-2', stars: 5),
      ).thenAnswer((_) async {}),
      build: build,
      act: (b) =>
          b.add(const TravelerRatingSubmitRequested(bidId: 'bid-2', stars: 5)),
      expect: () => [isA<RatingLoading>(), isA<RatingSuccess>()],
      verify: (_) => expect(rated, ['bid-2']),
    );

    blocTest<RatingBloc, RatingState>(
      '409 already-rated → signal',
      setUp: () => when(
        () => repo.submitTravelerRating(bidId: 'bid-2', stars: 3),
      ).thenThrow(const ConflictException('Conflict', code: 'already-rated')),
      build: build,
      act: (b) =>
          b.add(const TravelerRatingSubmitRequested(bidId: 'bid-2', stars: 3)),
      expect: () => [isA<RatingLoading>(), isA<RatingError>()],
      verify: (_) => expect(rated, ['bid-2']),
    );
  });

  test('sans service (instance de test) → aucun plantage', () async {
    when(
      () => repo.submitRating(bidId: 'bid-1', stars: 5),
    ).thenAnswer((_) async {});
    final bloc = RatingBloc(
      repo,
      makeDisabledAnalytics(MockAnalyticsBackend()),
    );
    bloc.add(const RatingSubmitRequested(bidId: 'bid-1', stars: 5));
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<RatingLoading>(), isA<RatingSuccess>()]),
    );
    await bloc.close();
  });

  test('service fermé → notifyRated ignoré', () async {
    final service = RatingEventsService();
    await service.dispose();
    expect(() => service.notifyRated('bid-1'), returnsNormally);
  });
}
