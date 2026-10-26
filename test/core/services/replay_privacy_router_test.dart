import 'dart:async';

import 'package:dony/core/services/replay_privacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Control implements ReplayRecordingControl {
  int stops = 0;
  int resumes = 0;

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> resume() async => resumes++;
}

/// Reproduit l'app : des onglets sur des navigateurs séparés. Un changement
/// d'onglet ne passe pas par les observateurs du navigateur racine : seul
/// l'écouteur du routeur le voit.
GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(body: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Text('home'),
              routes: [
                GoRoute(path: 'kyc', builder: (_, _) => const Text('kyc')),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const Text('profile')),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messages',
              builder: (_, _) => const Text('messages'),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/kyc/verify', builder: (_, _) => const Text('kyc-verify')),
  ],
);

void main() {
  late _Control control;
  late GoRouter router;
  late ReplayPrivacyObserver observer;

  setUp(() {
    control = _Control();
    router = _router();
    observer = ReplayPrivacyObserver(
      currentPath: () =>
          replayPathOf(router.routerDelegate.currentConfiguration),
      consentGranted: () => true,
      control: control,
    );
    router.routerDelegate.addListener(observer.evaluate);
  });

  tearDown(() async {
    router.routerDelegate.removeListener(observer.evaluate);
    await observer.dispose();
    router.dispose();
  });

  Future<void> pump(WidgetTester tester) =>
      tester.pumpWidget(MaterialApp.router(routerConfig: router));

  testWidgets('changement d\'onglet vers le profil : mis en pause', (
    tester,
  ) async {
    await pump(tester);
    expect(control.stops, 0);

    router.go('/profile');
    await tester.pumpAndSettle();
    expect(control.stops, 1);
    expect(observer.isPaused, isTrue);
  });

  testWidgets('retour à l\'accueil par l\'onglet : reprise', (tester) async {
    await pump(tester);
    router.go('/profile');
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();
    expect(control.resumes, 1);
    expect(observer.isPaused, isFalse);
  });

  testWidgets('onglet messages : mis en pause', (tester) async {
    await pump(tester);
    router.go('/messages');
    await tester.pumpAndSettle();
    expect(control.stops, 1);
  });

  testWidgets('page sensible poussée depuis un onglet : mise en pause', (
    tester,
  ) async {
    await pump(tester);
    unawaited(router.push<void>('/kyc/verify'));
    await tester.pumpAndSettle();
    expect(control.stops, 1);
  });

  testWidgets('navigation entre écrans ordinaires : jamais de pause', (
    tester,
  ) async {
    await pump(tester);
    router.go('/home/kyc');
    await tester.pumpAndSettle();
    expect(control.stops, 0);
  });
}
