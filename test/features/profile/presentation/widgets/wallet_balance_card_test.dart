import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/profile/presentation/widgets/wallet_balance_card.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/currency_test_doubles.dart';
import '../../../../helpers/l10n_test_helpers.dart';

class MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

Widget _wrap(MockWalletBloc bloc, MockBusinessPrefsBloc prefsBloc) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<WalletBloc>.value(value: bloc),
      BlocProvider<BusinessPrefsBloc>.value(value: prefsBloc),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: WalletBalanceCard()),
          ),
          GoRoute(
            path: '/payments/wallet',
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  const Text('WalletScreen'),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Retour'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/payments/wallet/topup/method',
            builder: (_, _) => const Scaffold(body: Text('TopupMethodScreen')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(WalletLoadRequested());
  });

  late MockWalletBloc bloc;
  late MockBusinessPrefsBloc prefsBloc;

  setUp(() {
    bloc = MockWalletBloc();
    prefsBloc = stubBusinessPrefsBloc();
  });

  testWidgets('état loading affiche un skeleton, pas de montant', (
    tester,
  ) async {
    whenListen<WalletState>(
      bloc,
      const Stream.empty(),
      initialState: WalletLoading(),
    );

    await tester.pumpWidget(_wrap(bloc, prefsBloc));
    // Un seul pump borné : l'entrée .animate() de _CardShell (fadeIn 300ms)
    // purge son timer interne, mais le shimmer du skeleton tourne
    // indéfiniment — pumpAndSettle n'y mettrait jamais fin.
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DonySkeletonBox), findsWidgets);
    expect(find.textContaining('Recharger'), findsNothing);
  });

  testWidgets('état chargé affiche le solde, la devise et Recharger', (
    tester,
  ) async {
    whenListen<WalletState>(
      bloc,
      const Stream.empty(),
      initialState: WalletLoaded(
        const WalletModel(balance: 128.5, currency: 'EUR', transactions: []),
      ),
    );

    await tester.pumpWidget(_wrap(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.textContaining('128,50'), findsOneWidget);
    expect(find.text('EUR'), findsWidgets);
    expect(find.text('Recharger'), findsOneWidget);
  });

  testWidgets(
    'nouveau contrat, deux devises : total estimé et détail par devise',
    (tester) async {
      whenListen<WalletState>(
        bloc,
        const Stream.empty(),
        initialState: WalletLoaded(
          const WalletModel(
            balance: 1.33,
            currency: 'EUR',
            estimatedTotal: 16.57,
            transactions: [],
            balances: [
              WalletCurrencyBalanceModel(
                currency: 'EUR',
                balance: 1.33,
                active: true,
                estimatedInActive: 1.33,
              ),
              WalletCurrencyBalanceModel(
                currency: 'XOF',
                balance: 10000,
                active: false,
                estimatedInActive: 15.24,
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(_wrap(bloc, prefsBloc));
      await tester.pumpAndSettle();

      expect(find.text('Total estimé'), findsOneWidget);
      expect(find.text('Solde'), findsNothing);
      expect(find.textContaining('16,57'), findsOneWidget);
      expect(find.byKey(const Key('profile-wallet-breakdown')), findsOneWidget);
      expect(find.textContaining('10'), findsWidgets);
      expect(find.text('Recharger'), findsOneWidget);
    },
  );

  testWidgets('nouveau contrat, une seule devise : carte Solde classique', (
    tester,
  ) async {
    whenListen<WalletState>(
      bloc,
      const Stream.empty(),
      initialState: WalletLoaded(
        const WalletModel(
          balance: 40,
          currency: 'EUR',
          estimatedTotal: 40,
          transactions: [],
          balances: [
            WalletCurrencyBalanceModel(
              currency: 'EUR',
              balance: 40,
              active: true,
              estimatedInActive: 40,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_wrap(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.text('Solde'), findsOneWidget);
    expect(find.text('Total estimé'), findsNothing);
    expect(find.byKey(const Key('profile-wallet-breakdown')), findsNothing);
  });

  testWidgets('devise USD affichée telle quelle (pas de valeur en dur)', (
    tester,
  ) async {
    whenListen<WalletState>(
      bloc,
      const Stream.empty(),
      initialState: WalletLoaded(
        const WalletModel(balance: 42, currency: 'USD', transactions: []),
      ),
    );

    await tester.pumpWidget(_wrap(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsWidgets);
    expect(find.text('EUR'), findsNothing);
  });

  testWidgets('tap sur la carte (hors bouton) ouvre /payments/wallet', (
    tester,
  ) async {
    whenListen<WalletState>(
      bloc,
      const Stream.empty(),
      initialState: WalletLoaded(
        const WalletModel(balance: 128.5, currency: 'EUR', transactions: []),
      ),
    );

    await tester.pumpWidget(_wrap(bloc, prefsBloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Solde'));
    await tester.pumpAndSettle();

    expect(find.text('WalletScreen'), findsOneWidget);
  });

  testWidgets('tap sur Recharger ouvre le flux de recharge, pas le wallet', (
    tester,
  ) async {
    whenListen<WalletState>(
      bloc,
      const Stream.empty(),
      initialState: WalletLoaded(
        const WalletModel(balance: 128.5, currency: 'EUR', transactions: []),
      ),
    );

    await tester.pumpWidget(_wrap(bloc, prefsBloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recharger'));
    await tester.pumpAndSettle();

    expect(find.text('TopupMethodScreen'), findsOneWidget);
    expect(find.text('WalletScreen'), findsNothing);
  });

  testWidgets(
    'retour depuis /payments/wallet rafraîchit le solde (recharge possible)',
    (tester) async {
      whenListen<WalletState>(
        bloc,
        const Stream.empty(),
        initialState: WalletLoaded(
          const WalletModel(balance: 128.5, currency: 'EUR', transactions: []),
        ),
      );

      await tester.pumpWidget(_wrap(bloc, prefsBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Solde'));
      await tester.pumpAndSettle();
      expect(find.text('WalletScreen'), findsOneWidget);

      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(any(that: isA<WalletLoadRequested>()))).called(1);
    },
  );

  testWidgets(
    'le badge devise n\'est plus interactif : le tap ouvre le portefeuille',
    (tester) async {
      whenListen<WalletState>(
        bloc,
        const Stream.empty(),
        initialState: WalletLoaded(
          const WalletModel(balance: 128.5, currency: 'EUR', transactions: []),
        ),
      );

      await tester.pumpWidget(_wrap(bloc, prefsBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EUR').first);
      await tester.pumpAndSettle();

      // Le badge n'a plus d'InkWell propre : le tap remonte à la carte
      // entière, qui ouvre toujours l'écran portefeuille.
      expect(find.text('Devise d\'affichage'), findsNothing);
      expect(find.text('WalletScreen'), findsOneWidget);
    },
  );

  testWidgets('état erreur affiche un message et un bouton réessayer', (
    tester,
  ) async {
    whenListen<WalletState>(
      bloc,
      const Stream.empty(),
      initialState: WalletError(const NetworkException('Erreur réseau')),
    );

    await tester.pumpWidget(_wrap(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.text('Solde indisponible'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    verify(() => bloc.add(any(that: isA<WalletLoadRequested>()))).called(1);
  });

  testWidgets('état chargé en anglais : Balance et Top up', (tester) async {
    useEnglish();
    whenListen<WalletState>(
      bloc,
      const Stream.empty(),
      initialState: WalletLoaded(
        const WalletModel(balance: 128.5, currency: 'EUR', transactions: []),
      ),
    );

    await tester.pumpWidget(_wrap(bloc, prefsBloc));
    await tester.pumpAndSettle();

    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Top up'), findsOneWidget);
  });
}
