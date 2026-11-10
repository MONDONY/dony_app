import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/money_keyword_warning.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const titleFr = "Envoi d'argent interdit";
  const titleEn = 'Sending money is prohibited';

  Widget wrap(TextEditingController ctrl, {Locale locale = AppL10n.fr}) =>
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: ctrl),
              MoneyKeywordWarning(controller: ctrl),
            ],
          ),
        ),
      );

  void narrowViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('rien tant que la description n\'évoque pas d\'argent', (
    tester,
  ) async {
    final ctrl = TextEditingController(text: 'vêtements');
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(wrap(ctrl));

    expect(find.byKey(MoneyKeywordWarning.bannerKey), findsNothing);
  });

  testWidgets('apparaît à la frappe, disparaît quand le terme est effacé', (
    tester,
  ) async {
    narrowViewport(tester);
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(wrap(ctrl));

    await tester.enterText(find.byType(TextField), 'cash');
    await tester.pumpAndSettle();
    final banner = find.byKey(MoneyKeywordWarning.bannerKey);
    expect(banner, findsOneWidget);
    expect(find.text(titleFr), findsOneWidget);
    expect(
      find.textContaining('ne peuvent pas être confiés à un voyageur'),
      findsOneWidget,
    );
    // Non bloquant : ni bouton d'action ni croix de fermeture.
    final bannerWidget = tester.widget<DonyStatusBanner>(banner);
    expect(bannerWidget.type, DonyStatusBannerType.warning);
    expect(bannerWidget.action, isNull);
    expect(bannerWidget.onDismiss, isNull);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
  });

  testWidgets('texte pré-rempli : bandeau affiché d\'emblée', (tester) async {
    final ctrl = TextEditingController(text: 'Une enveloppe d\'argent');
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(wrap(ctrl));

    expect(find.byKey(MoneyKeywordWarning.bannerKey), findsOneWidget);
  });

  testWidgets('en anglais, à 360 dp : texte traduit, aucun débordement', (
    tester,
  ) async {
    narrowViewport(tester);
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(wrap(ctrl, locale: AppL10n.en));

    await tester.enterText(find.byType(TextField), 'some money');
    await tester.pumpAndSettle();

    expect(find.text(titleEn), findsOneWidget);
    expect(
      find.textContaining('cannot be handed to a traveler'),
      findsOneWidget,
    );
    expect(find.text(titleFr), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
