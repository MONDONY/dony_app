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

  // `payment_succeeded` part de la feuille de paiement (PaymentSheetBloc),
  // avec le vrai moyen : la confirmation serveur ne le recompte plus.
  test('confirme au serveur sans recompter le paiement', () async {
    when(
      () => repo.confirmPayment('bid-1'),
    ).thenAnswer((_) async => _FakeBid());

    await confirmBidPaymentSafely('bid-1');
    await Future<void>.delayed(Duration.zero);

    verify(() => repo.confirmPayment('bid-1')).called(1);
    verifyNever(() => backend.capture(AnalyticsEvents.paymentSucceeded, any()));
  });

  test('un échec de confirmation ne remonte pas à l\'appelant', () async {
    // Stripe a encaissé : l'échec du filet client ne change rien au paiement.
    when(() => repo.confirmPayment('bid-1')).thenThrow(Exception('réseau'));

    await expectLater(confirmBidPaymentSafely('bid-1'), completes);
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => backend.capture(AnalyticsEvents.paymentSucceeded, any()));
  });
}
