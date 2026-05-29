import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late MockWalletRepository repo;
  late WalletBloc bloc;

  setUp(() {
    repo = MockWalletRepository();
    bloc = WalletBloc(repo);
  });

  tearDown(() => bloc.close());

  group('WalletLoadRequested', () {
    final wallet = WalletModel(balance: 42.50, currency: 'EUR', transactions: []);

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
        when(() => repo.topupStripe(amount: 50.0))
            .thenAnswer((_) async => 'pi_secret_test');
        return bloc;
      },
      act: (b) => b.add(WalletTopupRequested(amount: 50.0, paymentMethod: 'STRIPE')),
      expect: () => [isA<WalletLoading>(), isA<WalletTopupStripeReady>()],
    );
  });

  group('WalletTopupRequested — WAVE', () {
    blocTest<WalletBloc, WalletState>(
      'émet WalletTopupRedirectReady avec redirectUrl',
      build: () {
        when(() => repo.topupWave(amount: 20.0))
            .thenAnswer((_) async => 'https://wave.com/pay?...');
        return bloc;
      },
      act: (b) => b.add(WalletTopupRequested(amount: 20.0, paymentMethod: 'WAVE')),
      expect: () => [isA<WalletLoading>(), isA<WalletTopupRedirectReady>()],
    );
  });

  group('WalletTopupRequested — ORANGE_MONEY', () {
    blocTest<WalletBloc, WalletState>(
      'émet WalletTopupRedirectReady avec redirectUrl',
      build: () {
        when(() => repo.topupOrangeMoney(amount: 30.0))
            .thenAnswer((_) async => 'https://orange-money.com/pay?...');
        return bloc;
      },
      act: (b) => b.add(WalletTopupRequested(amount: 30.0, paymentMethod: 'ORANGE_MONEY')),
      expect: () => [isA<WalletLoading>(), isA<WalletTopupRedirectReady>()],
    );
  });

  group('WalletTopupRequested — réponse null', () {
    blocTest<WalletBloc, WalletState>(
      'émet WalletError si clientSecret null',
      build: () {
        when(() => repo.topupStripe(amount: 10.0))
            .thenAnswer((_) async => null);
        return bloc;
      },
      act: (b) => b.add(WalletTopupRequested(amount: 10.0, paymentMethod: 'STRIPE')),
      expect: () => [isA<WalletLoading>(), isA<WalletError>()],
    );
  });
}
