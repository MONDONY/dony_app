import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

void main() {
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;

  setUp(() async {
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
  });

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: firstStepsRoute,
      routes: [
        GoRoute(
          path: firstStepsRoute,
          builder: (_, _) => FirstStepsScreen(analytics: analytics),
        ),
        GoRoute(
          path: '/trips/publish-intro',
          builder: (_, _) => const Scaffold(body: Text('Trip intro')),
        ),
        GoRoute(
          path: '/parcels/send-intro',
          builder: (_, _) => const Scaffold(body: Text('Parcel intro')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home route')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pose la question et propose les deux premiers pas', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Votre compte est prêt'), findsOneWidget);
    expect(find.text('Je voyage'), findsOneWidget);
    expect(find.text("J'envoie un colis"), findsOneWidget);
    expect(find.text("Plus tard, aller à l'accueil"), findsOneWidget);
  });

  testWidgets('« Je voyage » ouvre l\'intro de publication d\'un trajet', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('first-steps-trip')));
    await tester.pumpAndSettle();

    expect(find.text('Trip intro'), findsOneWidget);
    verify(
      () =>
          backend.capture(AnalyticsEvents.firstStepsChoice, {'choice': 'trip'}),
    ).called(1);
  });

  testWidgets('« J\'envoie un colis » ouvre l\'intro d\'envoi', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('first-steps-parcel')));
    await tester.pumpAndSettle();

    expect(find.text('Parcel intro'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstStepsChoice, {
        'choice': 'parcel',
      }),
    ).called(1);
  });

  testWidgets('« Plus tard » mène à l\'accueil, comme avant', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('first-steps-later')));
    await tester.pumpAndSettle();

    expect(find.text('Home route'), findsOneWidget);
    verify(
      () => backend.capture(AnalyticsEvents.firstStepsChoice, {
        'choice': 'later',
      }),
    ).called(1);
  });
}
