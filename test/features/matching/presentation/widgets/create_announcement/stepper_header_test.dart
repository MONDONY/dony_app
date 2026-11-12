// Tests de CaStepperHeader : en-tête des étapes du formulaire « Publier un
// trajet », de 3 à 5 étapes selon la présence de Mode et de Conditions.
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_step.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

final _five = tripFormSteps(showModeStep: true);
final _four = tripFormSteps(showModeStep: false);

Future<void> _pump(
  WidgetTester tester,
  List<TripFormStep> steps,
  TripFormStep current, {
  Locale locale = AppL10n.fr,
  Size size = const Size(390, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    localizedApp(
      locale: locale,
      Padding(
        padding: const EdgeInsets.all(16),
        child: CaStepperHeader(steps: steps, current: current),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('CaStepperHeader', () {
    testWidgets('5 étapes, Prix courant : les trois premières cochées', (
      tester,
    ) async {
      await _pump(tester, _five, TripFormStep.prix);

      expect(find.text('Mode ✓'), findsOneWidget);
      expect(find.text('Trajet ✓'), findsOneWidget);
      expect(find.text('Capacité ✓'), findsOneWidget);
      expect(find.text('Prix'), findsOneWidget);
      expect(find.text('Conditions'), findsOneWidget);
      expect(find.textContaining('✓'), findsNWidgets(3));
      expect(find.byType(CaStepNode), findsNWidgets(5));
    });

    testWidgets('4 étapes sans Mode : pas de libellé Mode', (tester) async {
      await _pump(tester, _four, TripFormStep.trajet);

      expect(find.textContaining('Mode'), findsNothing);
      expect(find.text('Trajet'), findsOneWidget);
      expect(find.byType(CaStepNode), findsNWidgets(4));
      expect(find.textContaining('✓'), findsNothing);
    });

    testWidgets('trois étapes (écran en transition) : libellés Prix', (
      tester,
    ) async {
      await _pump(tester, const [
        TripFormStep.trajet,
        TripFormStep.capacite,
        TripFormStep.prix,
      ], TripFormStep.capacite);

      expect(find.text('Trajet ✓'), findsOneWidget);
      expect(find.text('Capacité'), findsOneWidget);
      expect(find.text('Prix'), findsOneWidget);
      expect(find.byType(CaStepNode), findsNWidgets(3));
    });

    testWidgets('labelFor remplace les libellés du formulaire', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        localizedApp(
          CaStepperHeader(
            steps: const [TripFormStep.trajet, TripFormStep.prix],
            current: TripFormStep.trajet,
            labelFor: (step, l) => switch (step) {
              TripFormStep.prix => l.tripPublishPriceConditionsStepLabel,
              _ => l.tripPublishRouteSectionLabel,
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Prix & conditions'), findsOneWidget);
      expect(find.text('Prix'), findsNothing);
    });

    testWidgets('libellés anglais', (tester) async {
      enableEnglish();
      await _pump(tester, _five, TripFormStep.conditions, locale: AppL10n.en);

      expect(find.text('Mode ✓'), findsOneWidget);
      expect(find.text('Trip ✓'), findsOneWidget);
      expect(find.text('Capacity ✓'), findsOneWidget);
      expect(find.text('Price ✓'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
    });

    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets('360 dp ${locale.languageCode} : aucun débordement, '
          'libellés sur une ligne', (tester) async {
        if (locale == AppL10n.en) enableEnglish();
        await _pump(
          tester,
          _five,
          TripFormStep.conditions,
          locale: locale,
          size: const Size(360, 800),
        );

        expect(tester.takeException(), isNull);
        final heights = {
          for (final t in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(CaStepperHeader),
              matching: find.byType(Text),
            ),
          ))
            if (t.data != null && t.data!.length > 2)
              t.data!: tester.getSize(find.text(t.data!)).height,
        };
        expect(heights.values.toSet().length, 1, reason: '$heights');
      });
    }
  });
}
