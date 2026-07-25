import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _pump(
  WidgetTester tester,
  TalonTravelerAction action, {
  String? travelerName,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TalonTravelerActionView(
            bidId: 'bid-1',
            action: action,
            travelerName: travelerName,
          ),
        ),
      ),
      GoRoute(
        path: '/tracking/scan',
        builder: (context, state) => const Scaffold(body: Text('SCANNER')),
      ),
      GoRoute(
        path: '/tracking/confirm',
        builder: (context, state) => const Scaffold(body: Text('RECEPTION')),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  return router;
}

void main() {
  testWidgets('mode scan → bouton "Scanner le colis"', (tester) async {
    await _pump(tester, TalonTravelerAction.scan);
    expect(find.text('Lire le QR du colis'), findsOneWidget);
  });

  testWidgets('mode confirmDelivery → bouton "Confirmer la livraison"', (
    tester,
  ) async {
    await _pump(
      tester,
      TalonTravelerAction.confirmDelivery,
      travelerName: 'Abou D.',
    );
    expect(find.text('Confirmer la livraison'), findsOneWidget);
  });

  testWidgets('tap scan → navigue vers /tracking/scan', (tester) async {
    await _pump(tester, TalonTravelerAction.scan);
    await tester.tap(find.text('Lire le QR du colis'));
    await tester.pumpAndSettle();
    expect(find.text('SCANNER'), findsOneWidget);
  });

  testWidgets('tap confirmDelivery → navigue vers /tracking/confirm', (
    tester,
  ) async {
    await _pump(
      tester,
      TalonTravelerAction.confirmDelivery,
      travelerName: 'Abou D.',
    );
    await tester.tap(find.text('Confirmer la livraison'));
    await tester.pumpAndSettle();
    expect(find.text('RECEPTION'), findsOneWidget);
  });
}
