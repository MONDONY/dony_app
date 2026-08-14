import 'package:dony/features/stripe_account/presentation/screens/account_disabled_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/account/disabled',
      routes: [
        GoRoute(
          path: '/account/disabled',
          builder: (_, _) => const AccountDisabledScreen(),
        ),
        GoRoute(
          path: '/connect/onboarding/intro',
          builder: (_, _) =>
              const Scaffold(body: Text('onboarding-intro-stub')),
        ),
      ],
    );
  });

  Widget buildWidget() => MaterialApp.router(routerConfig: router);

  testWidgets('annonce ce qui manque, sans parler de compte désactivé', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());

    expect(
      find.textContaining('Terminez la configuration'),
      findsOneWidget,
    );
    // L'ancien discours (« désactivé », « réactivation automatique par
    // Stripe ») laissait croire qu'il fallait attendre, alors que l'action
    // est du côté de l'utilisateur.
    expect(find.textContaining('désactivé'), findsNothing);
    expect(find.textContaining('réactivation automatique'), findsNothing);
  });

  testWidgets('liste les pièces à fournir', (tester) async {
    await tester.pumpWidget(buildWidget());

    expect(find.textContaining('identité'), findsOneWidget);
    expect(find.textContaining('IBAN'), findsOneWidget);
    expect(find.textContaining('conditions'), findsOneWidget);
  });

  testWidgets('le bouton principal mène à l\'onboarding Connect', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());

    await tester.tap(find.text('Compléter mes informations'));
    await tester.pumpAndSettle();

    expect(find.text('onboarding-intro-stub'), findsOneWidget);
  });

  testWidgets('le recours support est visible d\'emblée', (tester) async {
    await tester.pumpWidget(buildWidget());
    // Le bouton principal quitte l'écran : un support révélé après plusieurs
    // taps ne serait jamais atteignable.
    expect(find.text('Contacter le support Yadony'), findsOneWidget);
  });
}
