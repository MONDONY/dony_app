import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/settings/presentation/screens/change_pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockLocalAuthService extends Mock implements LocalAuthService {}

/// Router avec une route parente pour permettre context.pop() depuis /change-pin.
GoRouter _router(MockLocalAuthService svc, {bool isCreation = false}) =>
    GoRouter(
      initialLocation: '/change-pin',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Parent')),
          routes: [
            GoRoute(
              path: 'change-pin',
              builder: (_, _) =>
                  ChangePinScreen(authService: svc, isCreation: isCreation),
            ),
          ],
        ),
      ],
    );

void main() {
  late MockLocalAuthService svc;

  setUp(() {
    svc = MockLocalAuthService();
  });

  testWidgets('affiche le titre "Modifier le code PIN"', (tester) async {
    // Taille standard d'un téléphone (iPhone 14)
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(svc)));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le code PIN'), findsOneWidget);
  });

  testWidgets('affiche erreur si PIN actuel invalide', (tester) async {
    // Taille standard d'un téléphone (iPhone 14)
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => svc.validatePin(any())).thenAnswer((_) async => false);

    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(svc)));
    await tester.pumpAndSettle();

    // Saisir 6 chiffres via les boutons du keypad → déclenche validatePin
    // Utilise last pour cibler les boutons du keypad (après l'indicateur d'étapes)
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Attendre le Future.delayed(150ms) + résolution complète
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Code incorrect'), findsOneWidget);
  });

  testWidgets('transition à l\'étape 2 après PIN actuel valide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => svc.validatePin(any())).thenAnswer((_) async => true);

    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(svc)));
    await tester.pumpAndSettle();

    // Saisir 6 chiffres
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Doit maintenant afficher le titre étape 2
    expect(find.text('Créez votre nouveau code'), findsOneWidget);
  });

  testWidgets('sauvegarde le PIN après confirmation réussie', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => svc.validatePin(any())).thenAnswer((_) async => true);
    when(() => svc.savePin(any())).thenAnswer((_) async {});

    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(svc)));
    await tester.pumpAndSettle();

    // Étape 1 : PIN actuel
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Étape 2 : nouveau PIN
    for (final digit in ['9', '8', '7', '6', '5', '4']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Étape 3 : confirmation (même PIN)
    for (final digit in ['9', '8', '7', '6', '5', '4']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    verify(() => svc.savePin('987654')).called(1);
  });

  testWidgets('affiche erreur si confirmation PIN ne correspond pas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => svc.validatePin(any())).thenAnswer((_) async => true);

    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(svc)));
    await tester.pumpAndSettle();

    // Étape 1
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Étape 2 : nouveau PIN
    for (final digit in ['9', '8', '7', '6', '5', '4']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Étape 3 : confirmation différente
    for (final digit in ['1', '1', '1', '1', '1', '1']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Les codes ne correspondent pas'), findsOneWidget);
    // Retour à étape 2
    expect(find.text('Créez votre nouveau code'), findsOneWidget);
  });

  testWidgets('anglais : titre et sous-titre traduits', (tester) async {
    useEnglish();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(svc)));
    await tester.pumpAndSettle();

    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('Modifier le code PIN'), findsNothing);
  });

  testWidgets('anglais : code incorrect traduit', (tester) async {
    useEnglish();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => svc.validatePin(any())).thenAnswer((_) async => false);

    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(svc)));
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Incorrect code'), findsOneWidget);
  });

  group('indicateur d\'étapes (FLUTTER-H8)', () {
    Finder dot(int idx) => find.byKey(ValueKey('pin_step_dot_$idx'));

    bool isActive(WidgetTester tester, int idx) {
      final container = tester.widget<AnimatedContainer>(
        find.descendant(of: dot(idx), matching: find.byType(AnimatedContainer)),
      );
      final color = (container.decoration! as BoxDecoration).color;
      final primary = Theme.of(tester.element(dot(idx))).colorScheme.primary;
      return color == primary;
    }

    Future<void> pumpScreen(
      WidgetTester tester, {
      required bool creation,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: _router(svc, isCreation: creation)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('création : deux étapes, la première active au départ', (
      tester,
    ) async {
      await pumpScreen(tester, creation: true);

      expect(dot(0), findsOneWidget);
      expect(dot(1), findsOneWidget);
      expect(dot(2), findsNothing);
      expect(isActive(tester, 0), isTrue);
      expect(isActive(tester, 1), isFalse);
    });

    testWidgets('création : la seconde étape s\'active après la saisie', (
      tester,
    ) async {
      await pumpScreen(tester, creation: true);

      for (final digit in ['9', '8', '7', '6', '5', '4']) {
        await tester.tap(find.text(digit).last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(dot(2), findsNothing);
      expect(isActive(tester, 0), isTrue);
      expect(isActive(tester, 1), isTrue);
    });

    testWidgets('modification : trois étapes, seule la première active', (
      tester,
    ) async {
      await pumpScreen(tester, creation: false);

      expect(dot(0), findsOneWidget);
      expect(dot(1), findsOneWidget);
      expect(dot(2), findsOneWidget);
      expect(isActive(tester, 0), isTrue);
      expect(isActive(tester, 1), isFalse);
      expect(isActive(tester, 2), isFalse);
    });
  });
}
