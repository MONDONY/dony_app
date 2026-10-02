import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/screens/bid_accepted_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Future<GoRouter> openOverList(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/pending',
      routes: [
        GoRoute(
          path: '/pending',
          builder: (_, _) => const Scaffold(body: Text('À traiter')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Accueil')),
        ),
        GoRoute(
          path: '/bids/:bidId/accepted',
          builder: (_, state) =>
              BidAcceptedSuccessScreen(bidId: state.pathParameters['bidId']!),
        ),
        GoRoute(
          path: '/bids/:bidId',
          builder: (_, state) =>
              Scaffold(body: Text('Demande ${state.pathParameters['bidId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    unawaited(router.push('/bids/b-7/accepted'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('affiche titre, sous-titre et CTA en français', (tester) async {
    await openOverList(tester);

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Demande acceptée !'), findsOneWidget);
    expect(
      find.textContaining('Le colis est réservé sur ton trajet'),
      findsOneWidget,
    );
    expect(find.text('Voir la demande'), findsOneWidget);
  });

  testWidgets('le CTA ouvre la demande à la place de l\'écran, le retour '
      'ramène à la liste', (tester) async {
    final router = await openOverList(tester);

    await tester.ensureVisible(find.text('Voir la demande'));
    await tester.tap(find.text('Voir la demande'));
    await tester.pumpAndSettle();

    expect(find.text('Demande b-7'), findsOneWidget);
    expect(find.byType(DonySuccessScreen), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('À traiter'), findsOneWidget);
  });

  testWidgets('le bouton fermer revient à la liste', (tester) async {
    await openOverList(tester);

    await tester.tap(find.bySemanticsLabel('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('À traiter'), findsOneWidget);
    expect(find.text('Accueil'), findsNothing);
  });

  testWidgets('anglais : titre et CTA traduits', (tester) async {
    useEnglish();
    await openOverList(tester);

    expect(find.text('Request accepted!'), findsOneWidget);
    expect(find.text('View request'), findsOneWidget);
  });
}
