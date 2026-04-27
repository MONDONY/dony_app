import 'dart:io';

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

GoRouter _buildRouter() => GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const OnboardingScreen()),
      GoRoute(
        path: '/auth/phone',
        builder: (_, __) => const Scaffold(body: Text('Phone Auth')),
      ),
    ]);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: _buildRouter(),
  ));
  // Advance past all flutter_animate timers (longest delay is 380ms)
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('user_prefs');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    final box = Hive.box('user_prefs');
    await box.clear();
  });

  testWidgets('OnboardingScreen affiche les 2 CTAs', (tester) async {
    await _pump(tester);

    expect(find.text('J\'envoie un colis'), findsOneWidget);
    expect(find.text('Je suis voyageur'), findsOneWidget);
    expect(find.byType(DonyButton), findsNWidgets(2));
  });

  testWidgets('OnboardingScreen affiche 3 feature cards', (tester) async {
    await _pump(tester);

    expect(find.text('Vérifié'), findsOneWidget);
    expect(find.text('Tracé'), findsOneWidget);
    expect(find.text('Garanti'), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche le logo dony', (tester) async {
    await _pump(tester);

    // "dony" is a standalone Text widget in _DonyLogo
    expect(find.text('dony'), findsOneWidget);
    // "." is the green dot beside "dony"
    expect(find.text('.'), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche le headline principal', (tester) async {
    await _pump(tester);

    // "Envoyez un colis" is a standalone Text widget
    expect(find.text('Envoyez un colis'), findsOneWidget);
    // "chez vous, autrement." is a Text.rich — use textContaining
    expect(find.textContaining('chez vous'), findsOneWidget);
    expect(find.textContaining(', autrement.'), findsOneWidget);
  });

  testWidgets('OnboardingScreen affiche le footer CGU', (tester) async {
    await _pump(tester);

    // CGU text is inside a Text.rich widget — textContaining matches across the full text
    expect(find.textContaining('CGU'), findsOneWidget);
    expect(find.textContaining('politique de confidentialité'), findsOneWidget);
  });

  testWidgets('tapping primary CTA navigates to /auth/phone', (tester) async {
    await _pump(tester);

    await tester.tap(find.text("J'envoie un colis"));
    await tester.pumpAndSettle();

    expect(find.text('Phone Auth'), findsOneWidget);
  });
}
