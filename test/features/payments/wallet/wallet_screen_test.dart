import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_screen.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/currency_test_doubles.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

Widget buildSubject(WalletBloc bloc, BusinessPrefsBloc prefsBloc) =>
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => MultiBlocProvider(
              providers: [
                BlocProvider<WalletBloc>.value(value: bloc),
                BlocProvider<BusinessPrefsBloc>.value(value: prefsBloc),
              ],
              child: const WalletScreen(),
            ),
          ),
        ],
      ),
    );

void main() {
  late MockWalletBloc bloc;
  late MockBusinessPrefsBloc prefsBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(WalletLoadRequested());
    registerFallbackValue(const CurrencyChanged('EUR'));
  });

  setUp(() {
    bloc = MockWalletBloc();
    prefsBloc = stubBusinessPrefsBloc();
  });

  testWidgets('affiche le solde quand WalletLoaded', (tester) async {
    final wallet = WalletModel(
      balance: 47.50,
      currency: 'EUR',
      transactions: [],
    );
    whenListen(
      bloc,
      Stream.value(WalletLoaded(wallet)),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.textContaining('47'), findsAtLeastNWidgets(1));
    expect(find.text('Solde disponible'), findsOneWidget);
  });

  testWidgets('affiche un spinner quand WalletLoading', (tester) async {
    whenListen(
      bloc,
      Stream.value(WalletLoading()),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc, prefsBloc));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('le bouton Recharger est présent', (tester) async {
    final wallet = WalletModel(balance: 0, currency: 'EUR', transactions: []);
    whenListen(
      bloc,
      Stream.value(WalletLoaded(wallet)),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.text('Recharger'), findsOneWidget);
  });

  testWidgets('affiche un message erreur quand WalletError', (tester) async {
    whenListen(
      bloc,
      Stream.value(WalletError('Erreur réseau')),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.text('Erreur réseau'), findsOneWidget);
  });

  testWidgets('affiche les transactions quand non vide', (tester) async {
    final tx = WalletTransactionModel(
      type: 'TOP_UP',
      amount: 20.0,
      balanceAfter: 67.50,
      createdAt: DateTime(2026, 5, 1, 10, 30),
    );
    final wallet = WalletModel(
      balance: 67.50,
      currency: 'EUR',
      transactions: [tx],
    );
    whenListen(
      bloc,
      Stream.value(WalletLoaded(wallet)),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.text('Recharge'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
  });

  testWidgets(
    'affiche le label Parrainage pour une transaction REFERRAL_REWARD',
    (tester) async {
      final tx = WalletTransactionModel(
        type: 'REFERRAL_REWARD',
        amount: 5.0,
        balanceAfter: 5.0,
        createdAt: DateTime(2026, 5, 1, 10, 30),
      );
      final wallet = WalletModel(
        balance: 5.0,
        currency: 'EUR',
        transactions: [tx],
      );
      whenListen(
        bloc,
        Stream.value(WalletLoaded(wallet)),
        initialState: WalletInitial(),
      );

      await tester.pumpWidget(buildSubject(bloc, prefsBloc));
      await tester.pumpAndSettle();

      // Le type brut ne doit jamais s'afficher — toujours le label FR
      expect(find.text('Parrainage'), findsOneWidget);
      expect(find.text('REFERRAL_REWARD'), findsNothing);
    },
  );

  testWidgets('affiche le solde dans la devise active, pas toujours en EUR', (
    tester,
  ) async {
    final wallet = WalletModel(
      balance: 15.00,
      currency: 'CAD',
      transactions: [],
      balances: const [
        WalletCurrencyBalanceModel(
          currency: 'CAD',
          balance: 15.00,
          active: true,
        ),
      ],
    );
    whenListen(
      bloc,
      Stream.value(WalletLoaded(wallet)),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.textContaining('CA\$'), findsAtLeastNWidgets(1));
  });

  testWidgets('affiche les soldes verrouillés des devises non actives', (
    tester,
  ) async {
    final wallet = WalletModel(
      balance: 47.50,
      currency: 'EUR',
      transactions: [],
      balances: const [
        WalletCurrencyBalanceModel(
          currency: 'EUR',
          balance: 47.50,
          active: true,
        ),
        WalletCurrencyBalanceModel(
          currency: 'CAD',
          balance: 15.00,
          active: false,
        ),
      ],
    );
    whenListen(
      bloc,
      Stream.value(WalletLoaded(wallet)),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.textContaining('verrouillé'), findsOneWidget);
    expect(find.textContaining('Dollar canadien'), findsOneWidget);
  });

  testWidgets(
    'ne montre aucune section verrouillée si une seule devise possédée',
    (tester) async {
      final wallet = WalletModel(
        balance: 47.50,
        currency: 'EUR',
        transactions: [],
        balances: const [
          WalletCurrencyBalanceModel(
            currency: 'EUR',
            balance: 47.50,
            active: true,
          ),
        ],
      );
      whenListen(
        bloc,
        Stream.value(WalletLoaded(wallet)),
        initialState: WalletInitial(),
      );

      await tester.pumpWidget(buildSubject(bloc, prefsBloc));
      await tester.pumpAndSettle();

      expect(find.textContaining('verrouillé'), findsNothing);
    },
  );

  testWidgets(
    'tap sur un solde verrouillé propose de basculer vers cette devise',
    (tester) async {
      final wallet = WalletModel(
        balance: 47.50,
        currency: 'EUR',
        transactions: [],
        balances: const [
          WalletCurrencyBalanceModel(
            currency: 'EUR',
            balance: 47.50,
            active: true,
          ),
          WalletCurrencyBalanceModel(
            currency: 'CAD',
            balance: 15.00,
            active: false,
          ),
        ],
      );
      whenListen(
        bloc,
        Stream.value(WalletLoaded(wallet)),
        initialState: WalletInitial(),
      );

      await tester.pumpWidget(buildSubject(bloc, prefsBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Dollar canadien'));
      await tester.pumpAndSettle();

      expect(find.text('Changer de devise'), findsOneWidget);
      expect(find.text('Changer pour CAD'), findsOneWidget);
      verifyNever(() => prefsBloc.changeCurrency(any()));
    },
  );

  testWidgets(
    'confirmer la bascule d\'un solde verrouillé envoie CurrencyChanged '
    'et recharge le wallet',
    (tester) async {
      final wallet = WalletModel(
        balance: 47.50,
        currency: 'EUR',
        transactions: [],
        balances: const [
          WalletCurrencyBalanceModel(
            currency: 'EUR',
            balance: 47.50,
            active: true,
          ),
          WalletCurrencyBalanceModel(
            currency: 'CAD',
            balance: 15.00,
            active: false,
          ),
        ],
      );
      whenListen(
        bloc,
        Stream.value(WalletLoaded(wallet)),
        initialState: WalletInitial(),
      );

      await tester.pumpWidget(buildSubject(bloc, prefsBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Dollar canadien'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Changer pour CAD'));
      await tester.pumpAndSettle();

      verify(() => prefsBloc.changeCurrency('CAD')).called(1);
      // 1 au initState + 1 après la bascule de devise.
      verify(() => bloc.add(any(that: isA<WalletLoadRequested>()))).called(2);
    },
  );

  testWidgets('affiche message vide quand liste transactions vide', (
    tester,
  ) async {
    final wallet = WalletModel(balance: 0, currency: 'EUR', transactions: []);
    whenListen(
      bloc,
      Stream.value(WalletLoaded(wallet)),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.text('Aucune transaction pour l\'instant'), findsOneWidget);
  });
}
