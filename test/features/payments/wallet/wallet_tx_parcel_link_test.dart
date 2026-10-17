import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_active_currency_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_screen.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/currency_test_doubles.dart';
import '../../../helpers/l10n_test_helpers.dart';

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _MockActiveCurrencyCubit extends MockCubit<WalletActiveCurrencyState>
    implements WalletActiveCurrencyCubit {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

final _chevron = find.byWidgetPredicate(
  (w) => w is DonyIcon && w.name == 'chevron-right',
);

const _bidId = '3f2b6c1e-8a4d-4f6b-9c2e-1d7a5b3c9e0f';

Map<String, dynamic> _json({Object? bidId, bool withBidId = true}) => {
  'type': 'COMMISSION_DEDUCTED',
  'amount': -2.4,
  'currency': 'EUR',
  'balanceAfter': 17.6,
  'createdAt': '2026-10-15T10:30:00Z',
  if (withBidId) 'bidId': bidId,
};

/// Sentry FLUTTER-QP : « lorsque je clique sur une commission je veux être
/// redirigé sur le colis sur lequel la commission a été prélevée ».
void main() {
  group('WalletTransactionModel.bidId', () {
    test('lu quand le back l\'envoie', () {
      expect(
        WalletTransactionModel.fromJson(_json(bidId: _bidId)).bidId,
        _bidId,
      );
    });

    test('ancien back sans le champ : null', () {
      expect(
        WalletTransactionModel.fromJson(_json(withBidId: false)).bidId,
        isNull,
      );
    });

    test('null, vide ou d\'un autre type : null', () {
      expect(WalletTransactionModel.fromJson(_json()).bidId, isNull);
      expect(WalletTransactionModel.fromJson(_json(bidId: '  ')).bidId, isNull);
      expect(WalletTransactionModel.fromJson(_json(bidId: 42)).bidId, isNull);
    });

    test('lu aussi dans la liste du portefeuille', () {
      final wallet = WalletModel.fromJson({
        'balance': 17.6,
        'currency': 'EUR',
        'transactions': [
          _json(bidId: _bidId),
          {..._json(withBidId: false), 'type': 'TOP_UP', 'amount': 20},
        ],
      });
      expect(wallet.transactions.map((t) => t.bidId), [_bidId, null]);
    });
  });

  group('ligne de l\'historique', () {
    late _MockWalletBloc bloc;
    late _MockActiveCurrencyCubit currencyCubit;
    late MockBusinessPrefsBloc prefsBloc;
    late _MockAnalyticsService analytics;
    late List<String> opened;

    setUpAll(() async {
      await initializeDateFormatting('fr_FR');
      await initializeDateFormatting('en');
      registerFallbackValue(WalletLoadRequested());
    });

    setUp(() {
      bloc = _MockWalletBloc();
      prefsBloc = stubBusinessPrefsBloc();
      currencyCubit = _MockActiveCurrencyCubit();
      when(
        () => currencyCubit.state,
      ).thenReturn(const WalletActiveCurrencyState());
      when(() => currencyCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => currencyCubit.close()).thenAnswer((_) async {});
      analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
      getIt.registerSingleton<AnalyticsService>(analytics);
      addTearDown(() => getIt.unregister<AnalyticsService>());
      opened = [];
    });

    Future<void> pumpWallet(
      WidgetTester tester,
      List<WalletTransactionModel> transactions, {
      Locale locale = AppL10n.fr,
    }) async {
      whenListen(
        bloc,
        Stream.value(
          WalletLoaded(
            WalletModel(
              balance: 17.6,
              currency: 'EUR',
              transactions: transactions,
            ),
          ),
        ),
        initialState: WalletInitial(),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider<WalletBloc>.value(value: bloc),
                BlocProvider<BusinessPrefsBloc>.value(value: prefsBloc),
                BlocProvider<WalletActiveCurrencyCubit>.value(
                  value: currencyCubit,
                ),
              ],
              child: const WalletScreen(),
            ),
          ),
          GoRoute(
            path: '/bids/:bidId',
            builder: (context, state) {
              opened.add(state.pathParameters['bidId']!);
              return Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Fiche du colis'),
                ),
              );
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
    }

    WalletTransactionModel commission({String? bidId}) =>
        WalletTransactionModel(
          type: 'COMMISSION_DEDUCTED',
          amount: -2.4,
          currency: 'EUR',
          balanceAfter: 17.6,
          createdAt: DateTime(2026, 10, 15, 10, 30),
          bidId: bidId,
        );

    final parcelRow = find.byKey(const ValueKey('wallet-tx-parcel-$_bidId'));

    testWidgets('commission liée à un colis : chevron, tap, fiche du colis', (
      tester,
    ) async {
      await pumpWallet(tester, [commission(bidId: _bidId)]);

      expect(find.text('Commission'), findsOneWidget);
      expect(parcelRow, findsOneWidget);
      expect(
        find.descendant(of: parcelRow, matching: _chevron),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(parcelRow),
        isSemantics(isButton: true, hint: 'Voir le colis'),
      );

      await tester.tap(parcelRow);
      await tester.pumpAndSettle();

      expect(opened, [_bidId]);
      expect(find.text('Fiche du colis'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.walletTxParcelOpened,
          properties: {'type': 'COMMISSION_DEDUCTED'},
        ),
      ).called(1);

      // Retour : le solde se recharge sans spinner.
      await tester.tap(find.text('Fiche du colis'));
      await tester.pumpAndSettle();
      expect(find.text('Commission'), findsOneWidget);
      verify(
        () => bloc.add(any(that: isA<WalletRefreshRequested>())),
      ).called(1);
    });

    testWidgets('ligne sans colis (ancien back) : inchangée, non cliquable', (
      tester,
    ) async {
      await pumpWallet(tester, [commission()]);

      expect(find.text('Commission'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'wallet-tx-parcel-',
              ),
        ),
        findsNothing,
      );
      expect(_chevron, findsNothing);

      await tester.tap(find.text('Commission'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.walletTxParcelOpened,
          properties: any(named: 'properties'),
        ),
      );
    });

    testWidgets('paiement d\'un colis côté expéditeur : même fiche', (
      tester,
    ) async {
      await pumpWallet(tester, [
        WalletTransactionModel(
          type: 'BID_PAYMENT',
          amount: -24,
          currency: 'EUR',
          balanceAfter: 6,
          createdAt: DateTime(2026, 10, 15, 9),
          bidId: _bidId,
        ),
      ]);

      await tester.tap(parcelRow);
      await tester.pumpAndSettle();
      expect(opened, [_bidId]);
    });

    testWidgets('anglais : indication d\'accessibilité traduite', (
      tester,
    ) async {
      enableEnglish();
      await pumpWallet(tester, [commission(bidId: _bidId)], locale: AppL10n.en);

      expect(
        tester.getSemantics(parcelRow),
        isSemantics(isButton: true, hint: 'View parcel'),
      );
    });
  });
}
