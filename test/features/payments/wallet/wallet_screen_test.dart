import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_eligible_topups_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
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

class MockWalletRefundRequestCubit extends MockCubit<WalletRefundRequestState>
    implements WalletRefundRequestCubit {}

class MockWalletEligibleTopupsCubit extends MockCubit<WalletEligibleTopupsState>
    implements WalletEligibleTopupsCubit {}

// Réassigné à chaque test : la sheet de sélection (contrat legacy) le
// récupère via `getIt<WalletEligibleTopupsCubit>()`.
late MockWalletEligibleTopupsCubit _currentTopupsCubit;

Widget buildSubject(
  WalletBloc bloc,
  BusinessPrefsBloc prefsBloc, [
  WalletRefundRequestCubit? refundCubit,
]) => MaterialApp.router(
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<WalletBloc>.value(value: bloc),
            BlocProvider<BusinessPrefsBloc>.value(value: prefsBloc),
            if (refundCubit != null)
              BlocProvider<WalletRefundRequestCubit>.value(value: refundCubit),
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
  late MockWalletRefundRequestCubit refundCubit;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(WalletLoadRequested());
    if (!getIt.isRegistered<WalletEligibleTopupsCubit>()) {
      getIt.registerFactory<WalletEligibleTopupsCubit>(
        () => _currentTopupsCubit,
      );
    }
  });

  setUp(() {
    bloc = MockWalletBloc();
    prefsBloc = stubBusinessPrefsBloc();

    refundCubit = MockWalletRefundRequestCubit();
    when(() => refundCubit.state).thenReturn(const WalletRefundRequestState());
    when(() => refundCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => refundCubit.close()).thenAnswer((_) async {});
    when(() => refundCubit.submit(any())).thenAnswer((_) async {});

    _currentTopupsCubit = MockWalletEligibleTopupsCubit();
    when(
      () => _currentTopupsCubit.state,
    ).thenReturn(const WalletEligibleTopupsState());
    when(
      () => _currentTopupsCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => _currentTopupsCubit.close()).thenAnswer((_) async {});
    when(() => _currentTopupsCubit.load(any())).thenAnswer((_) async {});
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
      Stream.value(WalletError(const NetworkException('Erreur réseau'))),
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

  testWidgets(
    'affiche le label Remboursement pour une transaction SELF_REFUND_OUT',
    (tester) async {
      final tx = WalletTransactionModel(
        type: 'SELF_REFUND_OUT',
        amount: -10.0,
        balanceAfter: 10.0,
        createdAt: DateTime(2026, 8, 21, 8, 41),
      );
      final wallet = WalletModel(
        balance: 10.0,
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

      expect(find.text('Remboursement'), findsOneWidget);
      expect(find.text('SELF_REFUND_OUT'), findsNothing);
    },
  );

  testWidgets(
    'affiche l\'icône sablier et le délai pour une recharge en cours de remboursement',
    (tester) async {
      final tx = WalletTransactionModel(
        type: 'TOP_UP',
        amount: 10.0,
        balanceAfter: 20.0,
        createdAt: DateTime(2026, 8, 21, 7, 53),
        refundStatus: 'PROCESSING',
      );
      final wallet = WalletModel(
        balance: 20.0,
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

      expect(
        find.text('Remboursement en cours · sous 5 à 10 jours ouvrés'),
        findsOneWidget,
      );
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
      // Plus de « 0 € » codé en dur : le portefeuille peut être en XOF.
      expect(find.text('Devise à zéro'), findsOneWidget);
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
      // Demandes), les deux `findsNothing` ci-dessus ne sont donc pas vides
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

  testWidgets(
    'Rembourser ouvre la sheet de confirmation quand refundableAmount est connu',
    (tester) async {
      const wallet = WalletModel(
        balance: 40,
        currency: 'EUR',
        transactions: [],
        refundEligible: true,
        balances: [
          WalletCurrencyBalanceModel(
            currency: 'EUR',
            balance: 40,
            active: true,
            refundEligible: true,
            refundableAmount: 35,
            nonRefundableAmount: 5,
          ),
        ],
      );
      whenListen(
        bloc,
        Stream.value(WalletLoaded(wallet)),
        initialState: WalletInitial(),
      );

      await tester.pumpWidget(buildSubject(bloc, prefsBloc, refundCubit));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rembourser'));
      await tester.pumpAndSettle();

      expect(find.text('Rembourser mon solde'), findsOneWidget);
      expect(find.text('Choisir une recharge'), findsNothing);
    },
  );

  testWidgets('Rembourser ouvre la sheet de sélection sur l\'ancien contrat', (
    tester,
  ) async {
    const wallet = WalletModel(
      balance: 40,
      currency: 'EUR',
      transactions: [],
      refundEligible: true,
      balances: [
        WalletCurrencyBalanceModel(
          currency: 'EUR',
          balance: 40,
          active: true,
          refundEligible: true,
        ),
      ],
    );
    whenListen(
      bloc,
      Stream.value(WalletLoaded(wallet)),
      initialState: WalletInitial(),
    );
    // Sans ça, `WalletEligibleTopupsState()` par défaut (isLoading: true)
    // fait tourner un spinner en boucle et `pumpAndSettle` n'aboutit
    // jamais.
    when(
      () => _currentTopupsCubit.state,
    ).thenReturn(const WalletEligibleTopupsState(isLoading: false));

    await tester.pumpWidget(buildSubject(bloc, prefsBloc, refundCubit));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rembourser'));
    await tester.pumpAndSettle();

    expect(find.text('Choisir une recharge'), findsOneWidget);
  });
}
