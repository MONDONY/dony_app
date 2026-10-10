import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/models/commission_funding_alternative.dart';
import 'package:dony/features/matching/data/models/commission_shortfall.dart';
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
    'requires3ds → handleNextAction success → confirm rejected → BidFailed',
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
      when(() => repo.confirmCommissionAcceptance('bid_x')).thenAnswer(
        (_) async =>
            const ConfirmResponse(accepted: false, error: 'Carte refusée'),
      );
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptRequested('bid_x')),
    expect: () => [
      isA<BidAccepting>(),
      predicate<BidFailed>(
        (s) =>
            s.serverMessage == 'Carte refusée' &&
            s.reason == BidFailureReason.confirmFailed &&
            s.cardDeclined,
      ),
    ],
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
    expect: () => [
      isA<BidAccepting>(),
      predicate<BidFailed>(
        (s) =>
            s.reason == BidFailureReason.bankAuthInterrupted && s.cardDeclined,
      ),
    ],
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
      predicate<BidFailed>(
        (s) =>
            s.serverMessage == 'Carte refusée' &&
            s.reason == BidFailureReason.refused,
      ),
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
    expect: () => [
      isA<BidAccepting>(),
      predicate<BidFailed>(
        (s) => s.reason == BidFailureReason.refused && s.serverMessage == null,
      ),
    ],
  );

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'network error on card path emits BidFailed with no server message',
    build: () {
      when(
        () => repo.acceptBidWithCommission('bid_x', commissionSource: 'CARD'),
      ).thenThrow(Exception('timeout'));
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptWithCardRequested('bid_x')),
    expect: () => [
      isA<BidAccepting>(),
      predicate<BidFailed>(
        (s) => s.reason == BidFailureReason.refused && s.serverMessage == null,
      ),
    ],
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
          breakdown: CommissionShortfall(
            bidCurrency: 'XOF',
            commission: 1050,
            coveredByBidWallet: 600,
            remainingBid: 450,
            remainingInActive: 0.69,
            activeCurrency: 'EUR',
            activeBalance: 1.33,
          ),
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
            s.bidId == 'bid_x' &&
            s.breakdown?.bidCurrency == 'XOF' &&
            s.breakdown?.commission == 1050 &&
            s.breakdown?.coveredByBidWallet == 600 &&
            s.breakdown?.remainingBid == 450 &&
            s.breakdown?.remainingInActive == 0.69 &&
            s.breakdown?.activeCurrency == 'EUR' &&
            s.breakdown?.activeBalance == 1.33,
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

  blocTest<BidAcceptanceBloc, BidAcceptanceState>(
    'insufficient wallet carries bidCurrency and alternatives (FLUTTER-CG)',
    build: () {
      when(() => repo.acceptBidWithCommission('bid_x')).thenAnswer(
        (_) async => const AcceptanceResponse(
          status: AcceptanceStatus.insufficientWallet,
          availableBalance: 0,
          requiredCommission: 1,
          hasCard: false,
          currency: 'EUR',
          bidCurrency: 'EUR',
          alternatives: [
            CommissionFundingAlternative(
              currency: 'XOF',
              balance: 12000,
              requiredAmount: 656,
            ),
          ],
        ),
      );
      return BidAcceptanceBloc(repo, stripe);
    },
    act: (b) => b.add(BidAcceptRequested('bid_x')),
    expect: () => [
      isA<BidAccepting>(),
      isA<BidWalletInsufficient>()
          .having((s) => s.bidCurrency, 'bidCurrency', 'EUR')
          .having((s) => s.alternatives.single.currency, 'alternative', 'XOF'),
    ],
  );

  group(
    'refus définitif du serveur (staging 10/10 : 409 capacity-insufficient en boucle)',
    () {
      const capacity = ConflictException(
        'Capacité insuffisante',
        code: 'capacity-insufficient',
      );

      blocTest<BidAcceptanceBloc, BidAcceptanceState>(
        '409 capacity-insufficient → BidFailed définitif portant le code ; '
        'un second tap rejoue le refus sans rappeler le serveur',
        build: () {
          when(() => repo.acceptBidWithCommission('bid_x')).thenThrow(capacity);
          return BidAcceptanceBloc(repo, stripe);
        },
        act: (b) async {
          b.add(BidAcceptRequested('bid_x'));
          await Future<void>.delayed(Duration.zero);
          b.add(BidAcceptRequested('bid_x'));
        },
        expect: () => [
          isA<BidAccepting>(),
          isA<BidFailed>()
              .having((s) => s.definitive, 'definitive', isTrue)
              .having((s) => s.bidId, 'bidId', 'bid_x')
              .having((s) => s.error?.code, 'code', 'capacity-insufficient'),
          isA<BidFailed>().having((s) => s.definitive, 'definitive', isTrue),
        ],
        verify: (b) {
          verify(() => repo.acceptBidWithCommission('bid_x')).called(1);
          expect(b.refusals.keys, ['bid_x']);
        },
      );

      blocTest<BidAcceptanceBloc, BidAcceptanceState>(
        'la carte (CARD) est aussi rejouée sans appel une fois le refus connu',
        build: () {
          when(() => repo.acceptBidWithCommission('bid_x')).thenThrow(capacity);
          return BidAcceptanceBloc(repo, stripe);
        },
        act: (b) async {
          b.add(BidAcceptRequested('bid_x'));
          await Future<void>.delayed(Duration.zero);
          b.add(BidAcceptWithCardRequested('bid_x'));
        },
        skip: 2,
        expect: () => [
          isA<BidFailed>().having((s) => s.definitive, 'definitive', isTrue),
        ],
        verify: (_) {
          verifyNever(
            () =>
                repo.acceptBidWithCommission('bid_x', commissionSource: 'CARD'),
          );
        },
      );

      blocTest<BidAcceptanceBloc, BidAcceptanceState>(
        'après BidAcceptanceRefusalsCleared (liste rechargée), le serveur est '
        'de nouveau interrogé',
        build: () {
          when(() => repo.acceptBidWithCommission('bid_x')).thenThrow(capacity);
          return BidAcceptanceBloc(repo, stripe);
        },
        act: (b) async {
          b.add(BidAcceptRequested('bid_x'));
          await Future<void>.delayed(Duration.zero);
          b.add(BidAcceptanceRefusalsCleared());
          await Future<void>.delayed(Duration.zero);
          b.add(BidAcceptRequested('bid_x'));
        },
        verify: (b) {
          verify(() => repo.acceptBidWithCommission('bid_x')).called(2);
        },
      );

      blocTest<BidAcceptanceBloc, BidAcceptanceState>(
        'erreur passagère (réseau) → BidFailed non définitif, nouvel essai '
        'envoyé au serveur',
        build: () {
          when(
            () => repo.acceptBidWithCommission('bid_x'),
          ).thenThrow(const NetworkException('réseau'));
          return BidAcceptanceBloc(repo, stripe);
        },
        act: (b) async {
          b.add(BidAcceptRequested('bid_x'));
          await Future<void>.delayed(Duration.zero);
          b.add(BidAcceptRequested('bid_x'));
        },
        expect: () => [
          isA<BidAccepting>(),
          isA<BidFailed>().having((s) => s.definitive, 'definitive', isFalse),
          isA<BidAccepting>(),
          isA<BidFailed>().having((s) => s.definitive, 'definitive', isFalse),
        ],
        verify: (b) {
          verify(() => repo.acceptBidWithCommission('bid_x')).called(2);
          expect(b.refusals, isEmpty);
        },
      );
    },
  );
}
