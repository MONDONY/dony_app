import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/negotiation_commission_settled_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

void main() {
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Accueil')),
      ),
      GoRoute(
        path: '/negotiations/:id/commission-settled',
        builder: (_, state) => NegotiationCommissionSettledScreen(
          threadId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/negotiations/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Fil ${state.pathParameters['id']}')),
      ),
    ],
  );

  Future<GoRouter> openOverThread(WidgetTester tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    router.go('/negotiations/t1');
    await tester.pumpAndSettle();
    unawaited(router.push('/negotiations/t1/commission-settled'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('affiche titre, sous-titre et CTA en français', (tester) async {
    await openOverThread(tester);

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Ce colis est à vous !'), findsOneWidget);
    expect(
      find.textContaining('La commission Yadony est réglée'),
      findsOneWidget,
    );
    expect(find.text('Voir la négociation'), findsOneWidget);
  });

  testWidgets('le CTA ramène au fil, rechargé dessous', (tester) async {
    await openOverThread(tester);

    await tester.ensureVisible(find.text('Voir la négociation'));
    await tester.tap(find.text('Voir la négociation'));
    await tester.pumpAndSettle();

    expect(find.byType(DonySuccessScreen), findsNothing);
    expect(find.text('Fil t1'), findsOneWidget);
  });

  testWidgets('le bouton fermer ramène aussi au fil, pas à l\'accueil', (
    tester,
  ) async {
    await openOverThread(tester);

    await tester.tap(find.bySemanticsLabel('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Fil t1'), findsOneWidget);
    expect(find.text('Accueil'), findsNothing);
  });

  testWidgets('anglais : titre et CTA traduits', (tester) async {
    useEnglish();
    await openOverThread(tester);

    expect(find.text('This parcel is yours!'), findsOneWidget);
    expect(find.text('View negotiation'), findsOneWidget);
  });
}
