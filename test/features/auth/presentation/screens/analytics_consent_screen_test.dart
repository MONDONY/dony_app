import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/consent_prompt.dart';
import 'package:dony/features/auth/bloc/analytics_consent_cubit.dart';
import 'package:dony/features/auth/presentation/screens/analytics_consent_screen.dart';
import 'package:dony/features/auth/presentation/screens/profile_basics_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

/// Écran « Une dernière chose », juste après le code de vérification.
void main() {
  late _MockAnalytics analytics;
  late ConsentPrompt prompt;
  var requiresConsent = true;

  setUp(() {
    analytics = _MockAnalytics();
    prompt = ConsentPrompt();
    requiresConsent = true;
    when(() => analytics.syncFromBackend()).thenAnswer((_) async {});
    when(() => analytics.isConfigured).thenReturn(true);
    when(() => analytics.hasAnswered).thenReturn(false);
    when(
      () => analytics.setConsent(granted: any(named: 'granted')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    Size? size,
    String? next,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final router = GoRouter(
      initialLocation: analyticsConsentRoute,
      routes: [
        GoRoute(
          path: analyticsConsentRoute,
          builder: (_, _) => BlocProvider(
            create: (_) => AnalyticsConsentCubit(
              analytics,
              prompt,
              requiresConsent: () => requiresConsent,
            ),
            child: AnalyticsConsentScreen(next: next),
          ),
        ),
        GoRoute(
          path: '/auth/local',
          builder: (_, _) => const Scaffold(body: Text('Verrou local')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Accueil')),
        ),
        GoRoute(
          path: profileBasicsRoute,
          builder: (_, _) => const Scaffold(body: Text('Faisons connaissance')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder accept() => find.byKey(const Key('analytics-consent-accept'));

  testWidgets('zone RGPD : la question et ses quatre points s\'affichent', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Une dernière chose'), findsOneWidget);
    expect(
      find.textContaining('mesurer comment l\'app est utilisée'),
      findsOneWidget,
    );
    expect(
      find.text('Écrans visités et fonctionnalités utilisées'),
      findsOneWidget,
    );
    expect(
      find.text('Jamais vos paiements, cartes bancaires, identité ni messages'),
      findsOneWidget,
    );
    expect(find.text('Modifiable à tout moment dans Réglages'), findsOneWidget);
    expect(accept(), findsOneWidget);
    expect(find.widgetWithText(DonyButton, 'Accepter'), findsOneWidget);
    expect(find.text('Non merci'), findsOneWidget);
  });

  testWidgets(
    '« Accepter » : consentement accordé puis « Faisons connaissance »',
    (tester) async {
      prompt.request();
      await pump(tester);

      await tester.tap(accept());
      await tester.pumpAndSettle();

      verify(() => analytics.setConsent(granted: true)).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.analyticsConsentAnswered,
          properties: {'granted': true, 'surface': 'signup_screen'},
        ),
      ).called(1);
      expect(prompt.wanted.value, isFalse);
      expect(find.text('Faisons connaissance'), findsOneWidget);
      expect(find.text('Une dernière chose'), findsNothing);
    },
  );

  testWidgets('« Non merci » : consentement refusé, l\'inscription continue', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Non merci'));
    await tester.pumpAndSettle();

    verify(() => analytics.setConsent(granted: false)).called(1);
    expect(find.text('Faisons connaissance'), findsOneWidget);
  });

  testWidgets(
    'déjà répondu : l\'écran passe directement à la suite, sans afficher la '
    'question',
    (tester) async {
      when(() => analytics.hasAnswered).thenReturn(true);

      await pump(tester);

      expect(find.text('Une dernière chose'), findsNothing);
      expect(find.text('Faisons connaissance'), findsOneWidget);
      verifyNever(() => analytics.setConsent(granted: any(named: 'granted')));
    },
  );

  testWidgets('compte existant : « Accepter » mène à l\'accueil', (
    tester,
  ) async {
    await pump(tester, next: 'home');

    await tester.tap(accept());
    await tester.pumpAndSettle();

    verify(() => analytics.setConsent(granted: true)).called(1);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Faisons connaissance'), findsNothing);
  });

  testWidgets(
    'Google ou Apple, compte existant : « Accepter » mène au verrou',
    (tester) async {
      await pump(tester, next: 'local');

      await tester.tap(accept());
      await tester.pumpAndSettle();

      expect(find.text('Verrou local'), findsOneWidget);
    },
  );

  testWidgets('compte existant déjà répondu : directement l\'accueil', (
    tester,
  ) async {
    when(() => analytics.hasAnswered).thenReturn(true);

    await pump(tester, next: 'home');

    expect(find.text('Une dernière chose'), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);
  });

  testWidgets('hors zone RGPD : l\'écran passe son chemin', (tester) async {
    requiresConsent = false;

    await pump(tester);

    expect(find.text('Une dernière chose'), findsNothing);
    expect(find.text('Faisons connaissance'), findsOneWidget);
  });

  testWidgets('en anglais : titre, points et boutons traduits', (tester) async {
    await pump(tester, locale: const Locale('en'));

    expect(find.text('One last thing'), findsOneWidget);
    expect(
      find.text('Never your payments, bank cards, identity or messages'),
      findsOneWidget,
    );
    expect(find.widgetWithText(DonyButton, 'Accept'), findsOneWidget);
    expect(find.text('No thanks'), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    testWidgets('${size.width.toInt()} dp : aucun débordement, boutons '
        'visibles', (tester) async {
      await pump(tester, size: size);

      expect(tester.takeException(), isNull);
      expect(accept(), findsOneWidget);
      expect(find.text('Non merci'), findsOneWidget);
    });
  }
}
