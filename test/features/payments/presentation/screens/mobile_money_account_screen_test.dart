import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/presentation/screens/mobile_money_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends Mock implements MobileMoneyAccountBloc {}

// Écran de transition : liste en lecture seule des comptes (lot C, tâche 12).
// La tâche 13 réécrit l'écran et ce fichier.
void main() {
  late _MockBloc bloc;

  const orange = MobileMoneyPayoutAccount(
    id: 'a1',
    provider: 'ORANGE_CIV',
    providerLabel: 'Orange Money CI',
    brand: 'ORANGE',
    country: 'CI',
    currency: 'XOF',
    msisdnMasked: '+225 •••• 36',
  );

  setUpAll(() {
    // MobileMoneyAccountEvent est sealed : le fallback est un vrai événement.
    registerFallbackValue(const MobileMoneyAccountsRequested());
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    MobileMoneyAccountState state, {
    bool settle = true,
  }) async {
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<MobileMoneyAccountState>.value(state));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<MobileMoneyAccountBloc>.value(
            value: bloc,
            child: const MobileMoneyAccountScreen(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('état initial : indicateur de chargement', (tester) async {
    await pumpScreen(tester, const MobileMoneyAccountInitial(), settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Versement mobile money'), findsOneWidget);
  });

  testWidgets('chargement en cours : indicateur de chargement', (tester) async {
    await pumpScreen(tester, const MobileMoneyAccountLoading(), settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('liste lue : un compte par ligne, numéro masqué', (tester) async {
    await pumpScreen(
      tester,
      const MobileMoneyAccountLoaded(
        MobileMoneyPayoutAccounts(accounts: [orange]),
      ),
    );

    expect(find.text('Orange Money CI'), findsOneWidget);
    expect(find.text('+225 •••• 36'), findsOneWidget);
  });

  testWidgets('échec de lecture : « Réessayer » relit la liste', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const MobileMoneyAccountError(NetworkException('offline')),
    );

    await tester.tap(find.text('Réessayer'));

    verify(() => bloc.add(const MobileMoneyAccountsRequested())).called(1);
  });
}
