import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/consent_prompt.dart';
import 'package:dony/features/auth/presentation/widgets/analytics_consent_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalytics analytics;
  late ConsentPrompt prompt;

  setUp(() {
    analytics = _MockAnalytics();
    when(
      () => analytics.setConsent(
        granted: any(named: 'granted'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    prompt = ConsentPrompt()..request();
    getIt.registerSingleton<AnalyticsService>(analytics);
    getIt.registerSingleton<ConsentPrompt>(prompt);
  });

  tearDown(() => getIt.reset());

  Future<void> open(WidgetTester tester, {Locale locale = AppL10n.fr}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        locale: locale,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AnalyticsConsentSheet.show(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('Accepter enregistre granted true avec source manual', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('consent-sheet-accept')));
    await tester.pumpAndSettle();

    verify(
      // ignore: avoid_redundant_argument_values
      () => analytics.setConsent(granted: true, source: 'manual'),
    ).called(1);
    verify(
      () => analytics.logEvent(
        'analytics_consent_answered',
        properties: {'granted': true},
      ),
    ).called(1);
    expect(prompt.wanted.value, isFalse);
    expect(find.byKey(const Key('consent-sheet-accept')), findsNothing);
  });

  testWidgets('Refuser enregistre granted false', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('consent-sheet-decline')));
    await tester.pumpAndSettle();

    verify(
      // ignore: avoid_redundant_argument_values
      () => analytics.setConsent(granted: false, source: 'manual'),
    ).called(1);
    expect(prompt.wanted.value, isFalse);
    expect(find.byKey(const Key('consent-sheet-decline')), findsNothing);
  });

  testWidgets(
    "fermer par geste n'enregistre rien et laisse la demande active",
    (tester) async {
      await open(tester);
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('consent-sheet-accept')), findsNothing);
      verifyNever(
        () => analytics.setConsent(
          granted: any(named: 'granted'),
          source: any(named: 'source'),
        ),
      );
      expect(prompt.wanted.value, isTrue);
    },
  );

  testWidgets(
    'une écriture locale qui échoue ferme quand même la feuille et lève la '
    'demande',
    (tester) async {
      when(
        () => analytics.setConsent(
          granted: any(named: 'granted'),
          source: any(named: 'source'),
        ),
      ).thenThrow(StateError('Hive indisponible'));
      await open(tester);
      // L'erreur remonte hors du widget (callback async) : on l'intercepte
      // pour ne vérifier que ce qui doit survivre à l'échec.
      final errors = <Object>[];
      await runZonedGuarded(() async {
        await tester.tap(find.byKey(const Key('consent-sheet-accept')));
        await tester.pumpAndSettle();
      }, (e, _) => errors.add(e));

      expect(errors.single, isA<StateError>());
      expect(prompt.wanted.value, isFalse);
      expect(find.byKey(const Key('consent-sheet-accept')), findsNothing);
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    },
  );

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets(
      'les deux libellés tiennent sur une ligne à 360 dp (${locale.languageCode})',
      (tester) async {
        enableEnglish();
        await open(tester, locale: locale);

        expect(tester.takeException(), isNull);
        final accept = find.byKey(const Key('consent-sheet-accept'));
        final decline = find.byKey(const Key('consent-sheet-decline'));
        expect(tester.getSize(accept).height, 52);
        expect(tester.getSize(decline).height, 52);
        // Empilés : « Accepter » au-dessus, pleine largeur.
        expect(
          tester.getTopLeft(accept).dy < tester.getTopLeft(decline).dy,
          isTrue,
        );
        for (final f in [accept, decline]) {
          final text = find.descendant(of: f, matching: find.byType(Text));
          final box = tester.renderObject<RenderBox>(text.first);
          expect(box.size.height, lessThan(24), reason: 'une seule ligne');
        }
      },
    );
  }
}
