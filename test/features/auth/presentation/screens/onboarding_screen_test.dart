import 'dart:io';

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:bloc_test/bloc_test.dart';
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
        path: '/auth/phone',
        builder: (_, __) => const Scaffold(body: Text('Phone Auth')),
      ),
    ]);

Future<void> _pump(WidgetTester tester, AuthBloc authBloc) async {
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.light,
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

  testWidgets('OnboardingScreen affiche les 2 CTAs', (tester) async {
    await _pump(tester, mockAuthBloc);

    expect(find.text('J\'envoie un colis'), findsOneWidget);
    expect(find.text('Je suis voyageur'), findsOneWidget);
    expect(find.byType(DonyButton), findsNWidgets(2));
  });

  testWidgets('OnboardingScreen affiche 3 feature cards', (tester) async {
    await _pump(tester, mockAuthBloc);

    expect(find.text('Vérifié'), findsOneWidget);
    expect(find.text('Tracé'), findsOneWidget);
    expect(find.text('Garanti'), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche le logo dony', (tester) async {
    await _pump(tester, mockAuthBloc);

    // "dony" is a standalone Text widget in _DonyLogo
    expect(find.text('dony'), findsOneWidget);
    // "." is the green dot beside "dony"
    expect(find.text('.'), findsOneWidget);
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

  testWidgets('tapping primary CTA dispatches OnboardingCompleted and navigates to /auth/phone',
      (tester) async {
    await _pump(tester, mockAuthBloc);

    await tester.runAsync(() async {
      await tester.tap(find.text("J'envoie un colis"));
    });
    await tester.pumpAndSettle();

    verify(() => mockAuthBloc.add(const OnboardingCompleted())).called(1);
    expect(find.text('Phone Auth'), findsOneWidget);
    expect(Hive.box('user_prefs').get('onboarding_done'), isTrue);
  });

  testWidgets('tapping ghost CTA dispatches OnboardingCompleted and navigates to /auth/phone',
      (tester) async {
    await _pump(tester, mockAuthBloc);

    await tester.runAsync(() async {
      await tester.tap(find.text('Je suis voyageur'));
    });
    await tester.pumpAndSettle();

    verify(() => mockAuthBloc.add(const OnboardingCompleted())).called(1);
    expect(find.text('Phone Auth'), findsOneWidget);
    expect(Hive.box('user_prefs').get('onboarding_done'), isTrue);
  });
}
