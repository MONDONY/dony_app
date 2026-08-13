import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late MockWalletRepository repo;
  late WalletBloc bloc;

  setUp(() {
    repo = MockWalletRepository();
    final backend = MockAnalyticsBackend();
    final analytics = makeDisabledAnalytics(backend);
    analytics.onConfigured();
    bloc = WalletBloc(repo, analytics);
  });

  tearDown(() => bloc.close());

  group('WalletLoadRequested', () {
    final wallet = WalletModel(
      balance: 42.50,
      currency: 'EUR',
      transactions: [],
    );

    blocTest<WalletBloc, WalletState>(
      'émet [WalletLoading, WalletLoaded] sur succès',
      build: () {
        when(() => repo.getBalance()).thenAnswer((_) async => wallet);
        return bloc;
      },
      act: (b) => b.add(WalletLoadRequested()),
      expect: () => [isA<WalletLoading>(), isA<WalletLoaded>()],
    );

    blocTest<WalletBloc, WalletState>(
      'émet [WalletLoading, WalletError] sur erreur réseau',
      build: () {
        when(() => repo.getBalance()).thenThrow(Exception('network error'));
        return bloc;
      },
      act: (b) => b.add(WalletLoadRequested()),
      expect: () => [isA<WalletLoading>(), isA<WalletError>()],
    );
  });

  group('WalletTopupRequested — STRIPE', () {
    blocTest<WalletBloc, WalletState>(
      'émet WalletTopupStripeReady avec le clientSecret',
      build: () {
        when(
          () => repo.topupStripe(amount: 50.0),
        ).thenAnswer((_) async => 'pi_secret_test');
        return bloc;
      },
      act: (b) =>
          b.add(WalletTopupRequested(amount: 50.0, paymentMethod: 'STRIPE')),
      expect: () => [isA<WalletLoading>(), isA<WalletTopupStripeReady>()],
    );

    blocTest<WalletBloc, WalletState>(
      'transmet la devise locale CAD au top-up Stripe',
      build: () {
        when(
          () => repo.topupStripe(amount: 50.0, currencyCode: 'CAD'),
        ).thenAnswer((_) async => 'pi_secret_cad');
        return bloc;
      },
      act: (b) => b.add(
        WalletTopupRequested(
          amount: 50.0,
          paymentMethod: 'STRIPE',
          currencyCode: 'CAD',
        ),
      ),
      expect: () => [isA<WalletLoading>(), isA<WalletTopupStripeReady>()],
      verify: (_) => verify(
        () => repo.topupStripe(amount: 50.0, currencyCode: 'CAD'),
      ).called(1),
    );
  });

  group('WalletTopupRequested — réponse null', () {
    blocTest<WalletBloc, WalletState>(
      'émet WalletError si clientSecret null',
      build: () {
        when(
          () => repo.topupStripe(amount: 10.0),
        ).thenAnswer((_) async => null);
        return bloc;
      },
      act: (b) =>
          b.add(WalletTopupRequested(amount: 10.0, paymentMethod: 'STRIPE')),
      expect: () => [isA<WalletLoading>(), isA<WalletError>()],
    );
  });

  group('WalletRefreshRequested — pull-to-refresh', () {
    final wallet = WalletModel(balance: 75, currency: 'EUR', transactions: []);

    blocTest<WalletBloc, WalletState>(
      'émet WalletLoaded SANS WalletLoading (pas de flicker)',
      build: () {
        when(() => repo.getBalance()).thenAnswer((_) async => wallet);
        return bloc;
      },
      act: (b) => b.add(WalletRefreshRequested()),
      expect: () => [isA<WalletLoaded>()],
    );

    blocTest<WalletBloc, WalletState>(
      'émet WalletError sur échec',
      build: () {
        when(() => repo.getBalance()).thenThrow(Exception('network error'));
        return bloc;
      },
      act: (b) => b.add(WalletRefreshRequested()),
      expect: () => [isA<WalletError>()],
    );
  });

  group('WalletRefreshAfterTopupRequested — polling post-recharge', () {
    blocTest<WalletBloc, WalletState>(
      's\'arrête dès que le solde dépasse le précédent (1 seul fetch)',
      build: () {
        when(() => repo.getBalance()).thenAnswer(
          (_) async =>
              WalletModel(balance: 60, currency: 'EUR', transactions: []),
        );
        return bloc;
      },
      act: (b) => b.add(WalletRefreshAfterTopupRequested(50)),
      // Pas de WalletLoading (on garde le solde affiché) ; un seul WalletLoaded.
      expect: () => [isA<WalletLoaded>()],
      verify: (_) => verify(() => repo.getBalance()).called(1),
    );

    blocTest<WalletBloc, WalletState>(
      'continue de poller tant que le solde n\'a pas augmenté',
      build: () {
        var call = 0;
        when(() => repo.getBalance()).thenAnswer((_) async {
          call++;
          return WalletModel(
            balance: call >= 2 ? 60 : 50,
            currency: 'EUR',
            transactions: [],
          );
        });
        return bloc;
      },
      act: (b) => b.add(WalletRefreshAfterTopupRequested(50)),
      wait: const Duration(seconds: 3),
      // 1er fetch = 50 (inchangé) → 2e fetch = 60 (crédit arrivé) → stop.
      expect: () => [isA<WalletLoaded>(), isA<WalletLoaded>()],
      verify: (_) => verify(() => repo.getBalance()).called(2),
    );
  });
}
