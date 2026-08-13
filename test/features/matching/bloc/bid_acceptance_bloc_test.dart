import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBidRepository extends Mock implements BidRepository {}

class MockStripe extends Mock implements Stripe {}

PaymentIntent _fakePaymentIntent() => const PaymentIntent(
  id: 'pi_x',
  amount: 100,
  created: '1234567890',
  currency: 'eur',
  status: PaymentIntentsStatus.Succeeded,
  clientSecret: 'pi_x_secret',
  livemode: false,
  captureMethod: CaptureMethod.Automatic,
  confirmationMethod: ConfirmationMethod.Automatic,
);

void main() {
  late MockBidRepository repo;
  late MockStripe stripe;

  setUp(() {
    repo = MockBidRepository();
    stripe = MockStripe();
  });

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'accepted path emits BidAccepting then BidAccepted',
    build: () {
      when(() => repo.acceptBidWithCommission('bid_x')).thenAnswer(
        (_) async =>
            const AcceptanceResponse(status: AcceptanceStatus.accepted),
      );
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptRequested('bid_x')),
    expect: () => [isA<BidAccepting>(), isA<BidAccepted>()],
  );

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'requires3ds → handleNextAction success → BidAccepted',
    build: () {
      when(() => repo.acceptBidWithCommission('bid_x')).thenAnswer(
        (_) async => const AcceptanceResponse(
          status: AcceptanceStatus.requires3ds,
          clientSecret: 'pi_x',
        ),
      );
      when(
        () => stripe.handleNextAction('pi_x'),
      ).thenAnswer((_) async => _fakePaymentIntent());
      when(
        () => repo.confirmCommissionAcceptance('bid_x'),
      ).thenAnswer((_) async => const ConfirmResponse(accepted: true));
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptRequested('bid_x')),
    expect: () => [isA<BidAccepting>(), isA<BidAccepted>()],
  );

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'requires3ds → stripe throws StripeException → BidFailed',
    build: () {
      when(() => repo.acceptBidWithCommission('bid_x')).thenAnswer(
        (_) async => const AcceptanceResponse(
          status: AcceptanceStatus.requires3ds,
          clientSecret: 'pi_x',
        ),
      );
      when(() => stripe.handleNextAction('pi_x')).thenThrow(
        const StripeException(
          error: LocalizedErrorMessage(code: FailureCode.Canceled),
        ),
      );
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptRequested('bid_x')),
    expect: () => [isA<BidAccepting>(), isA<BidFailed>()],
  );

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'failed path emits BidFailed with error message',
    build: () {
      when(() => repo.acceptBidWithCommission('bid_x')).thenAnswer(
        (_) async => const AcceptanceResponse(
          status: AcceptanceStatus.failed,
          error: 'Carte refusée',
        ),
      );
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptRequested('bid_x')),
    expect: () => [
      isA<BidAccepting>(),
      predicate<BidFailed>((s) => s.message == 'Carte refusée'),
    ],
  );

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'network error emits BidFailed',
    build: () {
      when(
        () => repo.acceptBidWithCommission('bid_x'),
      ).thenThrow(Exception('timeout'));
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptRequested('bid_x')),
    expect: () => [isA<BidAccepting>(), isA<BidFailed>()],
  );

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'insufficientWallet emits BidWalletInsufficient with details',
    build: () {
      when(() => repo.acceptBidWithCommission('bid_x')).thenAnswer(
        (_) async => const AcceptanceResponse(
          status: AcceptanceStatus.insufficientWallet,
          availableBalance: 3.0,
          requiredCommission: 12.0,
          hasCard: true,
        ),
      );
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptRequested('bid_x')),
    expect: () => [
      isA<BidAccepting>(),
      predicate<BidWalletInsufficient>(
        (s) =>
            s.availableBalance == 3.0 &&
            s.requiredCommission == 12.0 &&
            s.hasCard == true &&
            s.bidId == 'bid_x',
      ),
    ],
  );

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'BidAcceptWithCardRequested forwards CARD source and accepts',
    build: () {
      when(
        () => repo.acceptBidWithCommission('bid_x', commissionSource: 'CARD'),
      ).thenAnswer(
        (_) async =>
            const AcceptanceResponse(status: AcceptanceStatus.accepted),
      );
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptWithCardRequested('bid_x')),
    expect: () => [isA<BidAccepting>(), isA<BidAccepted>()],
    verify: (_) {
      verify(
        () => repo.acceptBidWithCommission('bid_x', commissionSource: 'CARD'),
      ).called(1);
    },
  );

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'BidAcceptWithCardRequested with 3DS then confirm success → BidAccepted',
    build: () {
      when(
        () => repo.acceptBidWithCommission('bid_x', commissionSource: 'CARD'),
      ).thenAnswer(
        (_) async => const AcceptanceResponse(
          status: AcceptanceStatus.requires3ds,
          clientSecret: 'pi_x',
        ),
      );
      when(
        () => stripe.handleNextAction('pi_x'),
      ).thenAnswer((_) async => _fakePaymentIntent());
      when(
        () => repo.confirmCommissionAcceptance('bid_x'),
      ).thenAnswer((_) async => const ConfirmResponse(accepted: true));
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptWithCardRequested('bid_x')),
    expect: () => [isA<BidAccepting>(), isA<BidAccepted>()],
  );
}
