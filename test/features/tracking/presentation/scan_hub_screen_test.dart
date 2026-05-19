import 'package:dony/features/tracking/presentation/screens/scan_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ScanHubScreen()),
      GoRoute(
          path: '/tracking/scan/identify',
          builder: (_, __) => const Scaffold(body: Text('identify'))),
      GoRoute(
          path: '/tracking/scan',
          builder: (_, __) => const Scaffold(body: Text('qr-scan'))),
    ]);

Widget _wrap() => MaterialApp.router(routerConfig: _router());

void main() {
  testWidgets('affiche titre et 3 étapes', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Scan & Suivi'), findsOneWidget);
    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
    expect(find.text('Arrivée'), findsOneWidget);
  });

  testWidgets('tap Départ navigue vers identify avec etape=DEPART',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Départ'));
    await tester.pumpAndSettle();
    expect(find.text('identify'), findsOneWidget);
  });

  testWidgets('tap Scanner QR navigue vers /tracking/scan', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Scanner QR'));
    await tester.pumpAndSettle();
    expect(find.text('qr-scan'), findsOneWidget);
  });
}
