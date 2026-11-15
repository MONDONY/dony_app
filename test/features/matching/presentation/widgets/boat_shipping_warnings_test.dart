// Points à connaître avant d'envoyer par bateau : replié sur un résumé,
// détail à l'ouverture, textes français et anglais, analytics sans donnée du
// colis.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/presentation/widgets/boat_shipping_warnings.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalyticsService analytics;

  setUp(() {
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    BoatWarningsSource source = BoatWarningsSource.bidCreate,
  }) async {
    tester.view
      ..physicalSize = const Size(360, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BoatShippingWarnings(source: source, analytics: analytics),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boat-shipping-warnings-toggle')));
    await tester.pumpAndSettle();
  }

  testWidgets('replié : titre, résumé et bouton, pas de détail', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text("Avant d'envoyer par bateau"), findsOneWidget);
    expect(
      find.text(
        "Objets interdits, douane, délais et frais à l'arrivée : quelques "
        'points à connaître.',
      ),
      findsOneWidget,
    );
    expect(find.text('Voir les points à connaître'), findsOneWidget);
    expect(
      find.byKey(const Key('boat-shipping-warnings-details')),
      findsNothing,
    );
    final banner = tester.widget<DonyStatusBanner>(
      find.byType(DonyStatusBanner),
    );
    expect(banner.type, DonyStatusBannerType.warning);
  });

  testWidgets('ouvert en français : les cinq points', (tester) async {
    await pump(tester);
    await expand(tester);

    for (final text in [
      'Interdits en bateau',
      'Produits inflammables et aérosols, batteries lithium seules, '
          'médicaments, devises et espèces, armes même factices, denrées '
          'périssables, contrefaçons, produits animaux ou végétaux '
          'réglementés.',
      'Douane',
      'Les objets neufs et les quantités commerciales peuvent être taxés à '
          "l'arrivée. La douane peut ouvrir les colis : gardez une preuve de "
          'la valeur et photographiez le contenu.',
      'Délai',
      "Le départ peut être retardé si le conteneur n'est pas plein. Comptez "
          'en général 4 à 8 semaines.',
      "Frais à l'arrivée",
      'Des frais de manutention ou de stockage peuvent être demandés à '
          "l'arrivée, selon le transporteur.",
      'Emballage',
      "Protégez le colis de l'humidité. Les objets fragiles sont "
          'déconseillés.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text('Masquer le détail'), findsOneWidget);

    await expand(tester);
    expect(
      find.byKey(const Key('boat-shipping-warnings-details')),
      findsNothing,
    );
  });

  testWidgets('ouvert en anglais : les cinq points', (tester) async {
    await pump(tester, locale: AppL10n.en);
    expect(find.text('Before shipping by boat'), findsOneWidget);
    await expand(tester);

    for (final text in [
      'Not allowed by boat',
      'Customs',
      'Timing',
      'Expect 4 to 8 weeks in general.',
      'Fees on arrival',
      'Packing',
    ]) {
      expect(find.textContaining(text), findsWidgets, reason: text);
    }
    expect(find.text('Hide details'), findsOneWidget);
  });

  testWidgets('bouton : cible de 44 px au moins, état ouvert annoncé', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    final toggle = find.byKey(const Key('boat-shipping-warnings-toggle'));
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSemantics(toggle),
      isSemantics(
        label: 'Voir les points à connaître',
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: false,
      ),
    );
    await expand(tester);
    expect(
      tester.getSemantics(toggle),
      isSemantics(
        label: 'Masquer le détail',
        hasExpandedState: true,
        isExpanded: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('analytics : vue au premier affichage, ouverture une fois, '
      'seule la source part', (tester) async {
    await pump(tester, source: BoatWarningsSource.requestCreate);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.boatWarningsViewed,
        properties: {'source': 'request_create'},
      ),
    ).called(1);

    await expand(tester);
    await expand(tester);
    await expand(tester);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.boatWarningsExpanded,
        properties: {'source': 'request_create'},
      ),
    ).called(1);
  });
}
