import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/data/repositories/money_repository.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'money_fixtures.dart';

class MockMoneyRepository extends Mock implements MoneyRepository {}

class MockWalletRepository extends Mock implements WalletRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockMoneyRepository repo;
  late MockWalletRepository wallet;
  late MockAnalyticsService analytics;

  setUp(() {
    repo = MockMoneyRepository();
    wallet = MockWalletRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  MoneyOverviewBloc build({bool header = false}) => MoneyOverviewBloc(
    repo,
    wallet,
    analytics,
    fallbackToWallet: !header,
    trackViews: !header,
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'succès : chargement puis aperçu, consultation tracée une fois',
    build: () {
      when(() => repo.getOverview()).thenAnswer((_) async => overviewModel());
      return build();
    },
    act: (b) => b
      ..add(const MoneyOverviewLoadRequested())
      ..add(const MoneyOverviewRefreshRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewLoaded>()
          .having((s) => s.upcomingAvailable, 'upcomingAvailable', isTrue)
          .having((s) => s.overview.travelerItems.length, 'items', 4),
      isA<MoneyOverviewLoaded>(),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.moneyOverviewViewed,
        properties: {
          'traveler_items': 4,
          'sender_items': 1,
          'legacy_backend': false,
        },
      ),
    ).called(1),
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'vide : aperçu sans colis',
    build: () {
      when(
        () => repo.getOverview(),
      ).thenAnswer((_) async => const MoneyOverviewModel());
      return build();
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewLoaded>().having(
        (s) => s.overview.isEmpty,
        'isEmpty',
        isTrue,
      ),
    ],
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'erreur : état d\'erreur avec l\'exception typée',
    build: () {
      when(() => repo.getOverview()).thenThrow(const ServerException());
      return build();
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewError>().having(
        (s) => s.error,
        'error',
        isA<ServerException>(),
      ),
    ],
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'ancien back (404) : repli sur les soldes du portefeuille',
    build: () {
      when(
        () => repo.getOverview(),
      ).thenThrow(const MoneyOverviewUnavailable());
      when(() => wallet.getBalance()).thenAnswer(
        (_) async => const WalletModel(
          balance: 12.5,
          currency: 'EUR',
          transactions: [],
          balances: [
            WalletCurrencyBalanceModel(
              currency: 'EUR',
              balance: 12.5,
              active: true,
            ),
            WalletCurrencyBalanceModel(
              currency: 'XOF',
              balance: 3000,
              active: false,
            ),
          ],
        ),
      );
      return build();
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewLoaded>()
          .having((s) => s.upcomingAvailable, 'upcomingAvailable', isFalse)
          .having(
            (s) => s.overview.wallet.map((w) => w.currency).toList(),
            'wallet',
            ['EUR', 'XOF'],
          ),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.moneyOverviewViewed,
        properties: {
          'traveler_items': 0,
          'sender_items': 0,
          'legacy_backend': true,
        },
      ),
    ).called(1),
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'ancien back sans portefeuille détaillé : solde principal seul',
    build: () {
      when(
        () => repo.getOverview(),
      ).thenThrow(const MoneyOverviewUnavailable());
      when(() => wallet.getBalance()).thenAnswer(
        (_) async =>
            const WalletModel(balance: 4, currency: 'EUR', transactions: []),
      );
      return build();
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewLoaded>().having(
        (s) => s.overview.wallet.single.amount,
        'balance',
        4,
      ),
    ],
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'ancien back et portefeuille en échec : erreur',
    build: () {
      when(
        () => repo.getOverview(),
      ).thenThrow(const MoneyOverviewUnavailable());
      when(() => wallet.getBalance()).thenThrow(const OfflineException());
      return build();
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [isA<MoneyOverviewLoading>(), isA<MoneyOverviewError>()],
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'pastille (ancien back) : aucun appel portefeuille, aucun tracking',
    build: () {
      when(
        () => repo.getOverview(),
      ).thenThrow(const MoneyOverviewUnavailable());
      return build(header: true);
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewLoaded>().having(
        (s) => s.upcomingAvailable,
        'upcomingAvailable',
        isFalse,
      ),
    ],
    verify: (_) {
      verifyNever(() => wallet.getBalance());
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    },
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'pastille : succès sans tracking',
    build: () {
      when(() => repo.getOverview()).thenAnswer((_) async => overviewModel());
      return build(header: true);
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [isA<MoneyOverviewLoading>(), isA<MoneyOverviewLoaded>()],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  test('rafraîchissement raté : garde l\'aperçu affiché et termine le '
      'completer', () async {
    var calls = 0;
    when(() => repo.getOverview()).thenAnswer((_) async {
      calls++;
      if (calls == 1) return overviewModel();
      throw const OfflineException();
    });
    final bloc = build();
    bloc.add(const MoneyOverviewLoadRequested());
    await bloc.stream.firstWhere((s) => s is MoneyOverviewLoaded);
    final completer = Completer<void>();
    bloc.add(MoneyOverviewRefreshRequested(completer: completer));
    await completer.future;
    expect(bloc.state, isA<MoneyOverviewLoaded>());
    await bloc.close();
  });

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'rafraîchissement sans données préalables en échec : erreur',
    build: () {
      when(() => repo.getOverview()).thenThrow(const OfflineException());
      return build();
    },
    act: (b) => b.add(const MoneyOverviewRefreshRequested()),
    expect: () => [isA<MoneyOverviewError>()],
  );
}
