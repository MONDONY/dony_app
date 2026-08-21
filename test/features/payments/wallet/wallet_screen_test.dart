import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_screen.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/currency_test_doubles.dart';

class MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

Widget buildSubject(WalletBloc bloc, BusinessPrefsBloc prefsBloc) =>
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
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
  });

  setUp(() {
    bloc = MockWalletBloc();
    prefsBloc = stubBusinessPrefsBloc();
  });

  testWidgets('affiche le solde quand WalletLoaded', (tester) async {
    const wallet = WalletModel(
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

  testWidgets('affiche un skeleton quand WalletLoading', (tester) async {
    whenListen(
      bloc,
      Stream.value(WalletLoading()),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc, prefsBloc));
    await tester.pump();

    expect(find.byType(DonySkeletonCircle), findsWidgets);
  });

  testWidgets('le bouton Recharger est présent', (tester) async {
    const wallet = WalletModel(balance: 0, currency: 'EUR', transactions: []);
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
    const wallet = WalletModel(
      balance: 15.00,
      currency: 'CAD',
      transactions: [],
      balances: [
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
    const wallet = WalletModel(
      balance: 47.50,
      currency: 'EUR',
      transactions: [],
      balances: [
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
    'ne montre pas une devise non active à solde 0 comme verrouillée',
    (tester) async {
      const wallet = WalletModel(
        balance: 47.50,
        currency: 'EUR',
        transactions: [],
        balances: [
          WalletCurrencyBalanceModel(
            currency: 'EUR',
            balance: 47.50,
            active: true,
          ),
          WalletCurrencyBalanceModel(
            currency: 'CAD',
            balance: 0,
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

      // Rien n'est réellement bloqué à 0 : pas de tuile "verrouillé".
      expect(find.textContaining('verrouillé'), findsNothing);
      expect(find.textContaining('Dollar canadien'), findsNothing);
    },
  );

  testWidgets(
    'tap sur l\'icône info ouvre la sheet expliquant le portefeuille',
    (tester) async {
      const wallet = WalletModel(
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

      await tester.tap(find.byTooltip('Comment ça marche'));
      await tester.pumpAndSettle();

      expect(find.text('Comment fonctionne le portefeuille'), findsOneWidget);
      expect(find.text('Changer de devise'), findsOneWidget);
      expect(find.text('Devise à 0 €'), findsOneWidget);
    },
  );

  testWidgets(
    'ne montre aucune section verrouillée si une seule devise possédée',
    (tester) async {
      const wallet = WalletModel(
        balance: 47.50,
        currency: 'EUR',
        transactions: [],
        balances: [
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
    'un solde verrouillé ne propose plus de bascule : tap sans effet',
    (tester) async {
      const wallet = WalletModel(
        balance: 47.50,
        currency: 'EUR',
        transactions: [],
        balances: [
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

      expect(find.text('Changer de devise'), findsNothing);
      // Assertion probante : les deux entrées de solde (le solde actif du
      // hero et la ligne verrouillée) ne sont plus annoncées comme des
      // boutons. Seules les actions du hero le restent.
      final semanticsButton = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.button == true,
      );
      expect(
        find.ancestor(
          of: find.textContaining('Dollar canadien'),
          matching: semanticsButton,
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('Solde disponible'),
          matching: semanticsButton,
        ),
        findsNothing,
      );
      // Témoin : le prédicat trouve bien des boutons ailleurs (Recharger,
      // Utiliser), les deux `findsNothing` ci-dessus ne sont donc pas vides
      // de sens.
      expect(semanticsButton, findsWidgets);
      // 1 seul appel : celui de l'initState, aucun déclenché par le tap.
      verify(() => bloc.add(any(that: isA<WalletLoadRequested>()))).called(1);
    },
  );

  testWidgets('affiche message vide quand liste transactions vide', (
    tester,
  ) async {
    const wallet = WalletModel(balance: 0, currency: 'EUR', transactions: []);
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
