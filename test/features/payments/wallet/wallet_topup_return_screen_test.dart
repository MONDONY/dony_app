import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_return_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Écran de retour après checkout GeniusPay (dony://wallet/topup-return/{status}).
/// Ne crédite jamais le wallet lui-même — vérifie seulement l'affichage et la
/// navigation retour, le crédit réel reste porté par le webhook backend.
void main() {
  Widget buildHarness(String status) {
    final router = GoRouter(
      initialLocation: '/wallet/topup-return/$status',
      routes: [
        GoRoute(
          path: '/wallet/topup-return/:status',
          builder: (context, state) => WalletTopupReturnScreen(
            status: state.pathParameters['status'] ?? 'error',
          ),
        ),
        GoRoute(
          path: '/payments/wallet',
          builder: (_, __) => const Scaffold(body: Text('Wallet')),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
    );
  }

  testWidgets('status=success affiche le message de confirmation',
      (tester) async {
    await tester.pumpWidget(buildHarness('success'));
    await tester.pumpAndSettle();

    expect(find.text('Paiement confirmé'), findsOneWidget);
    expect(find.text('Ton solde sera crédité dans un instant.'),
        findsOneWidget);
  });

  testWidgets('status=error affiche le message d\'échec', (tester) async {
    await tester.pumpWidget(buildHarness('error'));
    await tester.pumpAndSettle();

    expect(find.text('Paiement non abouti'), findsOneWidget);
  });

  testWidgets('tap sur "Retour au portefeuille" navigue vers /payments/wallet',
      (tester) async {
    await tester.pumpWidget(buildHarness('success'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retour au portefeuille'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet'), findsOneWidget);
  });
}
