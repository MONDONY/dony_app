import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/analytics_consent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/mock_analytics_backend.dart';

/// Premier écran du parcours : aucun BLoC/Cubit propre, donc aucun harnais
/// avant cette tâche 4 (constructeur `const AnalyticsConsentScreen()` sans
/// paramètre). Verrouille le montage avec `progress` désormais requis.
const _progress = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.personalInfo,
    OnboardingStep.identity,
    OnboardingStep.payouts,
  ],
  done: {},
  current: OnboardingStep.consent,
);

Widget _wrap() => MaterialApp.router(
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const AnalyticsConsentScreen(progress: _progress),
      ),
      GoRoute(
        path: '/auth/country-selection',
        builder: (_, _) => const Scaffold(body: Text('Pays')),
      ),
    ],
  ),
);

void main() {
  setUp(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(
      makeDisabledAnalytics(MockAnalyticsBackend()),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  testWidgets('la jauge remplace le compteur en dur du tunnel', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DonyOnboardingGauge), findsOneWidget);
    expect(find.byType(DonyStepPill), findsNothing);
    // Position, pas remplissage : premier écran du parcours = « 1 / 5 ».
    expect(find.text('1 / 5 · Confidentialité'), findsOneWidget);
  });

  testWidgets('« Accepter » navigue vers la sélection de pays', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();

    expect(find.text('Pays'), findsOneWidget);
  });

  testWidgets('« Non merci » navigue aussi vers la sélection de pays', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Non merci'));
    await tester.pumpAndSettle();

    expect(find.text('Pays'), findsOneWidget);
  });
}
