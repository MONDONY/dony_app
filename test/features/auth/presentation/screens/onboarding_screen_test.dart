import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_logo.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
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

GoRouter _buildRouter(AuthBloc authBloc) => GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/method',
        builder: (_, __) => const Scaffold(body: Text('Auth Method')),
      ),
    ]);

Future<void> _pump(WidgetTester tester, AuthBloc authBloc) async {
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: _buildRouter(authBloc),
  ));
  // Advance past all flutter_animate timers (longest delay is 380ms)
  await tester.pump(const Duration(milliseconds: 500));
}

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

  testWidgets('OnboardingScreen affiche le CTA Commencer', (tester) async {
    await _pump(tester, mockAuthBloc);

    expect(find.text('Commencer'), findsOneWidget);
    expect(find.byType(DonyButton), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche 3 feature cards', (tester) async {
    await _pump(tester, mockAuthBloc);

    expect(find.text('Vérifié'), findsOneWidget);
    expect(find.text('Tracé'), findsOneWidget);
    expect(find.text('Garanti'), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche le logo yadony', (tester) async {
    await _pump(tester, mockAuthBloc);

    // DonyLogo is an Image.asset widget — verify it is present
    expect(find.byType(DonyLogo), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche le headline principal', (tester) async {
    await _pump(tester, mockAuthBloc);

    // "Envoyez un colis" is a standalone Text widget
    expect(find.text('Envoyez un colis'), findsOneWidget);
    // "chez vous, autrement." is a Text.rich — use textContaining
    expect(find.textContaining('chez vous'), findsOneWidget);
    expect(find.textContaining(', autrement.'), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche le footer CGU', (tester) async {
    await _pump(tester, mockAuthBloc);

    // CGU text is inside a Text.rich widget — textContaining matches across the full text
    expect(find.textContaining('CGU'), findsOneWidget);
    expect(find.textContaining('politique de confidentialité'), findsOneWidget);
  });

  testWidgets('tapping CTA Commencer navigates to /auth/method',
      (tester) async {
    await _pump(tester, mockAuthBloc);

    await tester.runAsync(() async {
      await tester.tap(find.text('Commencer'));
    });
    await tester.pumpAndSettle();

    verifyNever(() => mockAuthBloc.add(const OnboardingCompleted()));
    expect(find.text('Auth Method'), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche la mascotte joyeuse au-dessus du logo',
      (tester) async {
    await _pump(tester, mockAuthBloc);

    final mascotteFinder = find.byType(DonyMascotteAnimated);
    expect(mascotteFinder, findsOneWidget);

    final mascotte = tester.widget<DonyMascotteAnimated>(mascotteFinder);
    expect(mascotte.type, DonyMascotteType.joyeux);
    expect(mascotte.size, DonyMascotteSize.lg);
  });
}
