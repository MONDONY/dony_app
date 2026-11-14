// Tests de TransportModeRow : ligne compacte du mode, au-dessus des étapes du
// formulaire « Publier un trajet ».
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/transport_mode_row.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<TransportMode?> notifier, {
  List<TransportMode> modes = const [TransportMode.plane, TransportMode.car],
  bool readOnly = false,
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
      TransportModeRow(modes: modes, notifier: notifier, readOnly: readOnly),
    ),
  );
  await tester.pump();
}

void main() {
  group('TransportModeRow', () {
    testWidgets('libellé de section et une puce par mode', (tester) async {
      await _pump(tester, ValueNotifier(TransportMode.plane));

      expect(find.text('Mode de transport'), findsOneWidget);
      expect(find.text('Avion'), findsOneWidget);
      expect(find.text('Route'), findsOneWidget);
      final names = tester
          .widgetList<DonyIcon>(find.byType(DonyIcon))
          .map((i) => i.name);
      expect(names, containsAll(['plane', 'car']));
    });

    testWidgets('libellé de section en anglais', (tester) async {
      enableEnglish();
      await _pump(
        tester,
        ValueNotifier(TransportMode.plane),
        locale: AppL10n.en,
      );

      expect(find.text('Transport mode'), findsOneWidget);
      expect(find.text('Plane'), findsOneWidget);
      expect(find.text('Road'), findsOneWidget);
    });

    testWidgets('tap sur une puce change le mode', (tester) async {
      final notifier = ValueNotifier<TransportMode?>(TransportMode.plane);
      await _pump(tester, notifier);

      await tester.tap(find.text('Route'));
      await tester.pump();

      expect(notifier.value, TransportMode.car);
    });

    testWidgets('trajet BOAT existant affiché sélectionné', (tester) async {
      final semantics = tester.ensureSemantics();
      final notifier = ValueNotifier<TransportMode?>(TransportMode.boat);
      await _pump(tester, notifier);

      expect(find.text('Bateau'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('mode-chip-boat'))),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('mode-chip-plane'))),
        isSemantics(isSelected: false),
      );
      // Le mode courant est ajouté en tête.
      expect(
        tester.getTopLeft(find.byKey(const Key('mode-chip-boat'))).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('mode-chip-plane'))).dx,
        ),
      );
      semantics.dispose();
    });

    testWidgets('un bus est affiché Route et sélectionne la puce Route', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final notifier = ValueNotifier<TransportMode?>(TransportMode.bus);
      await _pump(tester, notifier);

      expect(find.text('Route'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('mode-chip-car'))),
        isSemantics(isSelected: true),
      );
      semantics.dispose();
    });

    testWidgets('mode absent : avion sélectionné', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, ValueNotifier(null));

      expect(
        tester.getSemantics(find.byKey(const Key('mode-chip-plane'))),
        isSemantics(isSelected: true),
      );
      semantics.dispose();
    });

    testWidgets('lecture seule : tap sans effet', (tester) async {
      final notifier = ValueNotifier<TransportMode?>(TransportMode.plane);
      await _pump(tester, notifier, readOnly: true);

      await tester.tap(find.text('Route'));
      await tester.pump();

      expect(notifier.value, TransportMode.plane);
    });

    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets('360 dp ${locale.languageCode} : aucun débordement', (
        tester,
      ) async {
        if (locale == AppL10n.en) enableEnglish();
        await _pump(
          tester,
          ValueNotifier(TransportMode.boat),
          locale: locale,
          size: const Size(360, 800),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
