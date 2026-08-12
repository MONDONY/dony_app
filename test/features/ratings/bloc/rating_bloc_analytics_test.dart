import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockRatingRepo extends Mock implements RatingRepository {}

void main() {
  late _MockRatingRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockRatingRepo();
    backend = MockAnalyticsBackend();
  });

  RatingBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return RatingBloc(repo, a);
  }

  test('rating_submitted fires with score=5 and role_rated=traveler on RatingSubmitRequested', () async {
    when(() => repo.submitRating(bidId: any(named: 'bidId'), stars: any(named: 'stars'), comment: any(named: 'comment')))
        .thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(const RatingSubmitRequested(bidId: 'bid1', stars: 5));
    await bloc.stream.firstWhere((s) => s is RatingSuccess);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.ratingSubmitted,
      {'score': 5, 'role_rated': 'traveler'},
    )).called(1);
  });

  test('rating_submitted fires with role_rated=sender on TravelerRatingSubmitRequested', () async {
    when(() => repo.submitTravelerRating(bidId: any(named: 'bidId'), stars: any(named: 'stars'), comment: any(named: 'comment')))
        .thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(const TravelerRatingSubmitRequested(bidId: 'bid1', stars: 4));
    await bloc.stream.firstWhere((s) => s is RatingSuccess);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.ratingSubmitted,
      {'score': 4, 'role_rated': 'sender'},
    )).called(1);
  });

  test('no event when disabled', () async {
    when(() => repo.submitRating(bidId: any(named: 'bidId'), stars: any(named: 'stars'), comment: any(named: 'comment')))
        .thenAnswer((_) async {});
    final bloc = makeBloc(enabled: false);
    bloc.add(const RatingSubmitRequested(bidId: 'bid1', stars: 5));
    await bloc.stream.firstWhere((s) => s is RatingSuccess);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
