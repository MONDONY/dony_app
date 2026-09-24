import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/screens/sender/negotiation_paid_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget wrap({String threadId = 't-1'}) {
    final router = GoRouter(
      initialLocation: '/negotiations/$threadId/paid',
      routes: [
        GoRoute(
          path: '/negotiations/:id/paid',
          builder: (_, state) => NegotiationPaidSuccessScreen(
            threadId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/negotiations/:id',
          builder: (_, state) => Scaffold(
            body: Center(
              child: Text('Fil de négociation ${state.pathParameters['id']}'),
            ),
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  testWidgets('affiche le titre, le sous-titre et le CTA en français', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Offre acceptée et payée !'), findsOneWidget);
    expect(
      find.textContaining('Ton argent est bloqué et sécurisé'),
      findsOneWidget,
    );
    expect(find.text('Voir le suivi'), findsOneWidget);
  });

  testWidgets('le CTA navigue vers le fil de négociation', (tester) async {
    await tester.pumpWidget(wrap(threadId: 'thread-42'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Voir le suivi'));
    await tester.tap(find.text('Voir le suivi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Fil de négociation thread-42'), findsOneWidget);
  });

  testWidgets('anglais : titre, sous-titre et CTA traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Offer accepted and paid!'), findsOneWidget);
    expect(
      find.textContaining('Your money is held and secured'),
      findsOneWidget,
    );
    expect(find.text('Track your shipment'), findsOneWidget);
  });
}
