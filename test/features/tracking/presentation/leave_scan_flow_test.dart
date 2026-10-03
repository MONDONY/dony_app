import 'dart:async';

import 'package:dony/features/tracking/presentation/screens/scan_confirm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// FLUTTER-9N : la fin d'un scan ramène à l'écran qui l'a lancé.
void main() {
  GoRouter router(String initial) => GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/tracking', builder: (_, _) => const Text('suivi')),
      GoRoute(path: '/bids/:id', builder: (_, _) => const Text('colis')),
      GoRoute(
        path: '/tracking/scan/photo',
        builder: (_, _) => const Text('photo'),
      ),
      GoRoute(
        path: '/tracking/scan/confirm',
        builder: (context, _) => TextButton(
          onPressed: () => leaveScanFlow(context),
          child: const Text('terminer'),
        ),
      ),
    ],
  );

  testWidgets('lancé depuis un colis : retour au colis', (tester) async {
    final r = router('/bids/b1');
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    unawaited(r.push('/tracking/scan/photo'));
    await tester.pumpAndSettle();
    unawaited(r.push('/tracking/scan/confirm'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('terminer'));
    await tester.pumpAndSettle();

    expect(find.text('colis'), findsOneWidget);
    expect(r.routerDelegate.currentConfiguration.uri.path, '/bids/b1');
  });

  testWidgets('rien dessous : onglet Suivi, comme avant', (tester) async {
    final r = router('/tracking/scan/confirm');
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();

    await tester.tap(find.text('terminer'));
    await tester.pumpAndSettle();

    expect(find.text('suivi'), findsOneWidget);
  });
}
