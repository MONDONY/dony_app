import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

Widget buildSubject(WalletBloc bloc) => MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => BlocProvider<WalletBloc>.value(
              value: bloc,
              child: const WalletScreen(),
            ),
          ),
        ],
      ),
    );

void main() {
  late MockWalletBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  setUp(() => bloc = MockWalletBloc());

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

    await tester.pumpWidget(buildSubject(bloc));
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

    await tester.pumpWidget(buildSubject(bloc));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('le bouton Recharger est présent', (tester) async {
    final wallet = WalletModel(
      balance: 0,
      currency: 'EUR',
      transactions: [],
    );
    whenListen(
      bloc,
      Stream.value(WalletLoaded(wallet)),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Recharger'), findsOneWidget);
  });

  testWidgets('affiche un message erreur quand WalletError', (tester) async {
    whenListen(
      bloc,
      Stream.value(WalletError('Erreur réseau')),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc));
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

    await tester.pumpWidget(buildSubject(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Recharge'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
  });

  testWidgets('affiche message vide quand liste transactions vide',
      (tester) async {
    final wallet = WalletModel(
      balance: 0,
      currency: 'EUR',
      transactions: [],
    );
    whenListen(
      bloc,
      Stream.value(WalletLoaded(wallet)),
      initialState: WalletInitial(),
    );

    await tester.pumpWidget(buildSubject(bloc));
    await tester.pumpAndSettle();

    expect(
      find.text('Aucune transaction pour l\'instant'),
      findsOneWidget,
    );
  });
}
