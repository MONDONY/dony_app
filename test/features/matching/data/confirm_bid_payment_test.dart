import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/confirm_bid_payment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockBidRepository extends Mock implements BidRepository {}

class _FakeBid extends Fake implements BidModel {}

void main() {
  late _MockBidRepository repo;
  late MockAnalyticsBackend backend;

  setUp(() async {
    await getIt.reset();
    repo = _MockBidRepository();
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    getIt
      ..registerSingleton<BidRepository>(repo)
      ..registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() => getIt.reset());

  test('compte le paiement carte de l\'offre et confirme au serveur', () async {
    when(
      () => repo.confirmPayment('bid-1'),
    ).thenAnswer((_) async => _FakeBid());

    await confirmBidPaymentSafely('bid-1');
    await Future<void>.delayed(Duration.zero);

    verify(() => repo.confirmPayment('bid-1')).called(1);
    final captured = verify(
      () => backend.capture(AnalyticsEvents.paymentSucceeded, captureAny()),
    ).captured;
    expect(captured.single, containsPair('context', 'bid'));
    expect(captured.single, containsPair('bid_id', 'bid-1'));
  });

  test('le paiement reste compté quand la confirmation échoue', () async {
    // Stripe a encaissé : l'échec du filet client ne change rien au paiement.
    when(() => repo.confirmPayment('bid-1')).thenThrow(Exception('réseau'));

    await confirmBidPaymentSafely('bid-1');
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.paymentSucceeded, any()),
    ).called(1);
  });
}
