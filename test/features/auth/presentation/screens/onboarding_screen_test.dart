import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_logo.dart';
import 'package:dony/core/design/widgets/dony_step_indicator.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mock AuthBloc ────────────────────────────────────────────────────────────
//
// We mock AuthBloc so no Firebase/Dio dependencies are needed in widget tests.
// OnboardingCompleted events are handled by writing to Hive, mirroring the real
// bloc handler, so navigation tests can assert on the Hive value.

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

GoRouter _buildRouter(AuthBloc authBloc) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: '/auth/method',
      builder: (_, _) => const Scaffold(body: Text('Auth Method')),
    ),
    GoRoute(
      path: '/legal/terms',
      builder: (_, _) => const Scaffold(body: Text('Page CGU')),
    ),
    GoRoute(
      path: '/legal/privacy',
      builder: (_, _) => const Scaffold(body: Text('Page confidentialité')),
    ),
  ],
);

Future<void> _pump(WidgetTester tester, AuthBloc authBloc) async {
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: _buildRouter(authBloc),
    ),
  );
  await tester.pumpAndSettle();
}

int _currentStep(WidgetTester tester) =>
    tester.widget<DonyStepIndicator>(find.byType(DonyStepIndicator)).current;

void main() {
  late Directory tempDir;
  late MockAuthBloc mockAuthBloc;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('user_prefs');

    registerFallbackValue(const OnboardingCompleted());
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());

    // When OnboardingCompleted is dispatched, write to Hive (mirrors real handler)
    when(() => mockAuthBloc.add(const OnboardingCompleted())).thenAnswer((_) {
      Hive.box('user_prefs').put('onboarding_done', true);
    });
  });

  tearDown(() async {
    await Hive.box('user_prefs').clear();
    await mockAuthBloc.close();
  });

  testWidgets('affiche la page accroche avec la première étape active', (
    tester,
  ) async {
    await _pump(tester, mockAuthBloc);

    expect(find.byType(DonyLogo), findsOneWidget);
    expect(find.text('Préparez votre envoi.'), findsOneWidget);
    expect(find.text('Créer l’annonce'), findsOneWidget);
    expect(find.text('Choisir un voyageur'), findsOneWidget);
    expect(find.text('Remettre le colis'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
    expect(find.byType(DonyButton), findsOneWidget);
    expect(_currentStep(tester), 0);
  });

  testWidgets('les CTA Suivant progressent vers les quatre pages', (
    tester,
  ) async {
    await _pump(tester, mockAuthBloc);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.byType(DonyLogo), findsOneWidget);
    expect(find.text('Chaque remise est encadrée.'), findsOneWidget);
    expect(find.text('Identité vérifiée'), findsOneWidget);
    expect(find.text('Paiement bloqué'), findsOneWidget);
    expect(find.text('QR de suivi'), findsOneWidget);
    expect(find.text('Preuve de remise'), findsOneWidget);
    expect(_currentStep(tester), 1);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Gardez le fil du colis.'), findsOneWidget);
    expect(find.text('Remis'), findsWidgets);
    expect(find.text('Départ, transit, arrivée'), findsOneWidget);
    expect(find.text('Livraison'), findsWidgets);
    expect(_currentStep(tester), 2);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Passer'), findsNothing);
    expect(find.text('Vos colis voyagent plus loin.'), findsOneWidget);
    expect(find.text('Remettre à l’arrivée'), findsOneWidget);
    expect(find.text('Libérer le paiement'), findsOneWidget);
    expect(find.textContaining('CGU'), findsOneWidget);
    expect(find.textContaining('politique de confidentialité'), findsOneWidget);
    expect(find.textContaining('Dony'), findsNothing);
    expect(_currentStep(tester), 3);
  });

  // Le test ci-dessus vérifiait que les deux libellés sont **affichés** sur la
  // dernière page. Ils l'étaient, soulignés et colorés, sans porter le moindre
  // `recognizer` : on demandait d'accepter des documents qu'aucun geste ne
  // permettait d'ouvrir.
  Future<void> gotoLastPage(WidgetTester tester) async {
    await _pump(tester, mockAuthBloc);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('toucher « CGU » ouvre la page des conditions', (tester) async {
    await gotoLastPage(tester);

    await tester.tapOnText(find.textRange.ofSubstring('CGU'));
    await tester.pumpAndSettle();

    expect(find.text('Page CGU'), findsOneWidget);
  });

  testWidgets('toucher « politique de confidentialité » ouvre la page dédiée', (
    tester,
  ) async {
    await gotoLastPage(tester);

    await tester.tapOnText(
      find.textRange.ofSubstring('politique de confidentialité'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Page confidentialité'), findsOneWidget);
  });

  testWidgets('le swipe horizontal fonctionne dans les deux sens', (
    tester,
  ) async {
    await _pump(tester, mockAuthBloc);

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(_currentStep(tester), 1);

    await tester.fling(find.byType(PageView), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();
    expect(_currentStep(tester), 0);
  });

  for (final startPage in [0, 1]) {
    testWidgets('Passer depuis la page ${startPage + 1} ouvre /auth/method', (
      tester,
    ) async {
      await _pump(tester, mockAuthBloc);
      if (startPage == 1) {
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();

      verifyNever(() => mockAuthBloc.add(const OnboardingCompleted()));
      expect(find.text('Auth Method'), findsOneWidget);
    });
  }

  testWidgets('Commencer conserve la destination finale /auth/method', (
    tester,
  ) async {
    await _pump(tester, mockAuthBloc);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    verifyNever(() => mockAuthBloc.add(const OnboardingCompleted()));
    expect(find.text('Auth Method'), findsOneWidget);
  });

  testWidgets('les étapes du parcours restent visibles sur un petit écran', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, mockAuthBloc);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    expect(find.text('Identité vérifiée').hitTestable(), findsOneWidget);
    expect(find.text('Paiement bloqué').hitTestable(), findsOneWidget);
    expect(find.text('QR de suivi').hitTestable(), findsOneWidget);
    expect(find.text('Preuve de remise').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
