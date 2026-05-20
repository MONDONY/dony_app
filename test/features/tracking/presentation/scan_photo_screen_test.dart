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
  // ─── Bouton Passer (optionnel) ─────────────────────────────────────────────
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

  // ─── Label du colis ────────────────────────────────────────────────────────
  testWidgets('affiche label du colis', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.text('DON-TEST01'), findsOneWidget);
  });

  // ─── Badges photo ─────────────────────────────────────────────────────────
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

  testWidgets('badge obligatoire pour ARRIVEE', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('ARRIVEE')));
    await tester.pump();
    expect(find.text('Photo obligatoire'), findsOneWidget);
  });

  // ─── Bouton "Prendre la photo" toujours présent ──────────────────────────
  testWidgets('bouton Prendre la photo présent pour DEPART', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.text('Prendre la photo'), findsOneWidget);
  });

  testWidgets('bouton Prendre la photo présent pour TRANSIT', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('TRANSIT')));
    await tester.pump();
    expect(find.text('Prendre la photo'), findsOneWidget);
  });

  // ─── Label étape visible ──────────────────────────────────────────────────
  testWidgets('DEPART — label étape Départ visible', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.textContaining('Départ'), findsOneWidget);
  });

  testWidgets('TRANSIT — label étape Transit visible', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('TRANSIT')));
    await tester.pump();
    expect(find.textContaining('Transit'), findsOneWidget);
  });

  testWidgets('ARRIVEE — label étape Arrivée visible', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('ARRIVEE')));
    await tester.pump();
    expect(find.textContaining('Arrivée'), findsOneWidget);
  });

  // ─── Icône fermeture ─────────────────────────────────────────────────────
  testWidgets('icône close présente', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  // ─── Titre écran ─────────────────────────────────────────────────────────
  testWidgets('titre Photo du colis affiché', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.text('Photo du colis'), findsOneWidget);
  });

  // ─── Géolocalisation label ────────────────────────────────────────────────
  testWidgets('label Géolocalisation automatique affiché', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.text('Géolocalisation automatique'), findsOneWidget);
  });
}
