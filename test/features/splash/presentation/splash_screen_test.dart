import 'package:dony/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fits a small screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(body: SplashContent(hasError: false)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('splash-brand-logo')), findsOneWidget);
    expect(find.text('Livrez vos colis en confiance'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caps the logo width on a tablet', (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: SplashContent(hasError: false)),
        ),
      ),
    );
    await tester.pump();

    final size = tester.getSize(find.byKey(const Key('splash-brand-logo')));
    expect(size.width, lessThanOrEqualTo(560));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a reachable retry action in error state', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SplashContent(hasError: true, onRetry: () => retried = true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Impossible de se connecter'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);

    final buttonSize = tester.getSize(find.byType(OutlinedButton));
    expect(buttonSize.height, greaterThanOrEqualTo(44));
  });
}
