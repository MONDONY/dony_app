import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _pump(WidgetTester tester, TalonTravelerAction action) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: TalonTravelerActionView(bidId: 'bid-1', action: action),
        ),
      ),
      GoRoute(
        path: '/tracking/scan',
        builder: (_, __) => const Scaffold(body: Text('SCANNER')),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  return router;
}

void main() {
  testWidgets('mode scan → bouton "Scanner le colis"', (tester) async {
    await _pump(tester, TalonTravelerAction.scan);
    expect(find.text('Scanner le colis'), findsOneWidget);
  });

  testWidgets('mode confirmDelivery → bouton "Confirmer la livraison"', (
    tester,
  ) async {
    await _pump(tester, TalonTravelerAction.confirmDelivery);
    expect(find.text('Confirmer la livraison'), findsOneWidget);
  });

  testWidgets('tap → navigue vers /tracking/scan', (tester) async {
    await _pump(tester, TalonTravelerAction.scan);
    await tester.tap(find.text('Scanner le colis'));
    await tester.pumpAndSettle();
    expect(find.text('SCANNER'), findsOneWidget);
  });
}
