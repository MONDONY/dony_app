import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockBidRepo extends Mock implements BidRepository {}
class _MockStripe extends Mock implements Stripe {}

void main() {
  late _MockBidRepo repo;
  late _MockStripe stripe;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockBidRepo();
    stripe = _MockStripe();
    backend = MockAnalyticsBackend();
  });

  BidAcceptanceBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return BidAcceptanceBloc(repo, stripe, a);
  }

  test('bid_accepted fires with bid_id on acceptance', () async {
    when(() => repo.acceptBidWithCommission('bid1'))
        .thenAnswer((_) async => const AcceptanceResponse(status: AcceptanceStatus.accepted));
    final bloc = makeBloc();
    bloc.add(BidAcceptRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is BidAccepted);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.bidAccepted, {'bid_id': 'bid1'})).called(1);
  });

  test('no event when disabled', () async {
    when(() => repo.acceptBidWithCommission('bid1'))
        .thenAnswer((_) async => const AcceptanceResponse(status: AcceptanceStatus.accepted));
    final bloc = makeBloc(enabled: false);
    bloc.add(BidAcceptRequested('bid1'));
    await bloc.stream.firstWhere((s) => s is BidAccepted);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
