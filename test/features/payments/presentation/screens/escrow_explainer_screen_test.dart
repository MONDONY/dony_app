import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/payments/presentation/screens/escrow_explainer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _buildRouter({
  required double amount,
  required String travelerName,
  String? bidId,
  String? stubTarget,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => EscrowExplainerScreen(
          amount: amount,
          travelerName: travelerName,
          bidId: bidId,
        ),
      ),
      if (stubTarget != null)
        GoRoute(
          path: stubTarget,
          builder: (_, __) => const Scaffold(body: Text('target')),
        ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  double amount = 120.50,
  String travelerName = 'Ibrahima',
  String? bidId,
  String? stubTarget,
}) async {
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: _buildRouter(
      amount: amount,
      travelerName: travelerName,
      bidId: bidId,
      stubTarget: stubTarget,
    ),
  ));
  await tester.pump();
}

void main() {
  group('EscrowExplainerScreen', () {
    testWidgets('shows formatted amount in amount card', (tester) async {
      await _pump(tester, amount: 120.50);
      expect(find.text('120,50'), findsOneWidget);
    });

    testWidgets('shows traveler name in amount card subtitle', (tester) async {
      await _pump(tester, travelerName: 'Fatou');
      expect(find.textContaining('Fatou'), findsWidgets);
    });

    testWidgets('shows insurance card with 200€ guarantee', (tester) async {
      await _pump(tester);
      expect(find.textContaining('200 €'), findsOneWidget);
    });

    testWidgets('shows 4 how-it-works steps', (tester) async {
      await _pump(tester);
      expect(find.text('Vous payez'), findsOneWidget);
      expect(find.text('Ibrahima livre'), findsOneWidget);
      expect(find.text('Fatou confirme'), findsOneWidget);
      expect(find.text('Ibrahima est payé'), findsOneWidget);
    });

    testWidgets('step 3 mentions code à 4 chiffres', (tester) async {
      await _pump(tester);
      expect(find.textContaining('code à 4 chiffres'), findsOneWidget);
    });

    testWidgets('CTA navigates to bid detail when bidId provided', (tester) async {
      await _pump(
        tester,
        bidId: 'abc123',
        stubTarget: '/bids/abc123',
      );
      await tester.ensureVisible(find.text('Voir le suivi'));
      await tester.tap(find.text('Voir le suivi'));
      await tester.pumpAndSettle();
      expect(find.text('target'), findsOneWidget);
    });

    testWidgets('shows Voir le suivi CTA when bidId is null', (tester) async {
      await _pump(tester);
      expect(find.text('Voir le suivi'), findsOneWidget);
    });

    testWidgets('shows appbar title Garde de confiance', (tester) async {
      await _pump(tester);
      expect(find.text('Garde de confiance'), findsOneWidget);
    });
  });
}
