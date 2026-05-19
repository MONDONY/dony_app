import 'package:dony/features/tracking/presentation/screens/scan_photo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router(String etape) => GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ScanPhotoScreen(
          bidId: 'test-bid-id',
          etape: etape,
          packageLabel: 'DON-TEST01',
        ),
      ),
      GoRoute(
          path: '/tracking/scan/confirm',
          builder: (_, __) => const Scaffold(body: Text('confirm'))),
    ]);

void main() {
  testWidgets('DEPART — pas de bouton Passer', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.text('Passer — continuer sans photo'), findsNothing);
  });

  testWidgets('ARRIVEE — pas de bouton Passer', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('ARRIVEE')));
    await tester.pump();
    expect(find.text('Passer — continuer sans photo'), findsNothing);
  });

  testWidgets('TRANSIT — bouton Passer visible', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('TRANSIT')));
    await tester.pump();
    expect(find.text('Passer — continuer sans photo'), findsOneWidget);
  });

  testWidgets('affiche label du colis', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.text('DON-TEST01'), findsOneWidget);
  });

  testWidgets('badge obligatoire pour DEPART', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.text('Photo obligatoire'), findsOneWidget);
  });

  testWidgets('badge optionnelle pour TRANSIT', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('TRANSIT')));
    await tester.pump();
    expect(find.text('Photo optionnelle'), findsOneWidget);
  });
}
