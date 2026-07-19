import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Widget tests du picker de méthode de recharge wallet (étape 1/2).
///
/// GeniusPay exige countryCode/phoneNumber pour toute recharge WAVE/ORANGE_MONEY
/// (backend : 422 topup-phone-required sinon) — cet écran doit donc collecter
/// ces 2 champs avant de pousser vers l'étape montant, et bloquer "Suivant"
/// tant qu'ils ne sont pas renseignés.
void main() {
  Map<String, dynamic>? pushedExtra;

  Widget buildHarness() {
    pushedExtra = null;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const WalletTopupMethodScreen(),
        ),
        GoRoute(
          path: '/payments/wallet/topup/amount',
          builder: (context, state) {
            pushedExtra = state.extra as Map<String, dynamic>;
            return const Scaffold(body: Text('Étape montant'));
          },
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

  testWidgets('STRIPE sélectionné → aucun champ mobile money, Suivant activé',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.tap(find.text('Carte bancaire'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mm-phone-field')), findsNothing);
    expect(find.byKey(const Key('mm-country-field')), findsNothing);

    final button = tester.widget<DonyButton>(find.byType(DonyButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
      'WAVE sélectionné → champs téléphone/pays affichés, Suivant désactivé tant que vides',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.tap(find.text('Wave'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mm-phone-field')), findsOneWidget);
    expect(find.byKey(const Key('mm-country-field')), findsOneWidget);

    final button = tester.widget<DonyButton>(find.byType(DonyButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
      'ORANGE_MONEY + téléphone rempli → Suivant activé, extra transmis avec countryCode/phoneNumber',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.tap(find.text('Orange Money'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('mm-phone-field')),
      '+2250701234567',
    );
    await tester.pumpAndSettle();

    // Pays par défaut = SN (Sénégal), déjà renseigné — Suivant doit s'activer.
    final button = tester.widget<DonyButton>(find.byType(DonyButton));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byType(DonyButton));
    await tester.pumpAndSettle();

    expect(pushedExtra, isNotNull);
    expect(pushedExtra!['method'], 'ORANGE_MONEY');
    expect(pushedExtra!['countryCode'], 'SN');
    expect(pushedExtra!['phoneNumber'], '+2250701234567');
  });

  testWidgets('STRIPE → extra ne contient ni countryCode ni phoneNumber',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.tap(find.text('Carte bancaire'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DonyButton));
    await tester.pumpAndSettle();

    expect(pushedExtra, isNotNull);
    expect(pushedExtra!['method'], 'STRIPE');
    expect(pushedExtra!.containsKey('countryCode'), isFalse);
    expect(pushedExtra!.containsKey('phoneNumber'), isFalse);
  });

  testWidgets(
      'changement de pays → nouvelle valeur transmise dans extra',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.tap(find.text('Wave'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('mm-phone-field')),
      '+221771234567',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mm-country-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Côte d\'Ivoire').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DonyButton));
    await tester.pumpAndSettle();

    expect(pushedExtra!['countryCode'], 'CI');
  });
}
