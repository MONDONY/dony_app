import 'package:dony/features/profile/presentation/widgets/activate_card_payments_cta_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Wrappe la carte dans un GoRouter minimal — nécessaire car
/// `ActivateCardPaymentsCtaCard` appelle `context.push('/payments/onboarding')`.
Widget _wrap(String? stripeStatus, {VoidCallback? onOnboardingPushed}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ActivateCardPaymentsCtaCard(stripeStatus: stripeStatus),
        ),
      ),
      GoRoute(
        path: '/payments/onboarding',
        builder: (context, state) {
          onOnboardingPushed?.call();
          return const Scaffold(body: Text('Onboarding'));
        },
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets(
    'affichée quand Stripe incomplet, CTA vers /payments/onboarding',
    (tester) async {
      var pushed = false;
      await tester.pumpWidget(
        _wrap('NOT_CREATED', onOnboardingPushed: () => pushed = true),
      );

      expect(find.byType(ActivateCardPaymentsCtaCard), findsOneWidget);
      expect(find.text('Activer les paiements par carte'), findsOneWidget);

      await tester.tap(find.byType(ActivateCardPaymentsCtaCard));
      await tester.pumpAndSettle();

      expect(pushed, isTrue);
      expect(find.text('Onboarding'), findsOneWidget);
    },
  );

  testWidgets('affichée quand stripeStatus est null (utilisateur non chargé)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(null));
    await tester.pumpAndSettle();

    expect(find.byType(ActivateCardPaymentsCtaCard), findsOneWidget);
  });

  testWidgets('masquée quand ONBOARDING_COMPLETE', (tester) async {
    await tester.pumpWidget(_wrap('ONBOARDING_COMPLETE'));

    expect(find.text('Activer les paiements par carte'), findsNothing);
    expect(find.byType(InkWell), findsNothing);

    // La carte se réduit à un widget de taille nulle (SizedBox.shrink()).
    final size = tester.getSize(find.byType(ActivateCardPaymentsCtaCard));
    expect(size, Size.zero);
  });
}
