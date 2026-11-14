// Tests de ModeStep : première étape du formulaire « Publier un trajet »
// quand le voyageur a le choix du mode. Widget sans état : il lit et écrit un
// ValueNotifier créé ici.
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/mode_step.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<TransportMode?> notifier, {
  List<TransportMode> modes = const [TransportMode.plane, TransportMode.car],
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
      SingleChildScrollView(
        child: ModeStep(modes: modes, notifier: notifier),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ModeStep', () {
    testWidgets('titre, sous-titre et une carte par mode (FR)', (tester) async {
      await _pump(tester, ValueNotifier(null));

      expect(find.text('Comment voyagez-vous ?'), findsOneWidget);
      expect(
        find.text('Le mode adapte la suite : dates, capacité et prix.'),
        findsOneWidget,
      );
      expect(find.text('Voie aérienne'), findsOneWidget);
      expect(find.text('Avion, vos kilos de valise'), findsOneWidget);
      expect(find.text('Quelques jours'), findsOneWidget);
      expect(find.text('Valises ou kg'), findsOneWidget);
      expect(find.text('Voie terrestre'), findsOneWidget);
      expect(find.text('Voiture, car ou camion'), findsOneWidget);
      expect(find.text('Même pays ou international'), findsOneWidget);
      expect(find.text('Kg libre ou exact'), findsOneWidget);
    });

    testWidgets('textes anglais', (tester) async {
      enableEnglish();
      await _pump(tester, ValueNotifier(null), locale: AppL10n.en);

      expect(find.text('How are you traveling?'), findsOneWidget);
      expect(find.text('By air'), findsOneWidget);
      expect(find.text('By road'), findsOneWidget);
      expect(find.text('Domestic or international'), findsOneWidget);
    });

    testWidgets('icônes du mode : plane et car', (tester) async {
      await _pump(tester, ValueNotifier(null));

      final names = tester
          .widgetList<DonyIcon>(find.byType(DonyIcon))
          .map((i) => i.name)
          .toList();
      expect(names, containsAll(['plane', 'car']));
    });

    testWidgets('tap sur Route sélectionne car', (tester) async {
      final notifier = ValueNotifier<TransportMode?>(null);
      await _pump(tester, notifier);

      await tester.tap(find.text('Voie terrestre'));
      await tester.pump();

      expect(notifier.value, TransportMode.car);
    });

    testWidgets('tap sur Avion sélectionne plane', (tester) async {
      final notifier = ValueNotifier<TransportMode?>(TransportMode.car);
      await _pump(tester, notifier);

      await tester.tap(find.text('Voie aérienne'));
      await tester.pump();

      expect(notifier.value, TransportMode.plane);
    });

    testWidgets('la carte sélectionnée est signalée (Semantics et coche)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final notifier = ValueNotifier<TransportMode?>(TransportMode.plane);
      await _pump(tester, notifier);

      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Voie aérienne'))),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Voie terrestre'))),
        isSemantics(isSelected: false),
      );
      expect(find.byKey(const Key('mode-check-plane')), findsOneWidget);
      expect(find.byKey(const Key('mode-check-car')), findsNothing);

      notifier.value = TransportMode.car;
      await tester.pump();

      expect(find.byKey(const Key('mode-check-plane')), findsNothing);
      expect(find.byKey(const Key('mode-check-car')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('bordure unie cs.primary sur la carte sélectionnée, sans '
        'dégradé', (tester) async {
      await _pump(tester, ValueNotifier(TransportMode.car));

      final primary = Theme.of(
        tester.element(find.byType(ModeStep)),
      ).colorScheme.primary;
      final decorations = tester
          .widgetList<DecoratedBox>(find.byKey(const Key('mode-card-car')))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>();
      expect(decorations.any((d) => d.border?.top.color == primary), isTrue);
      expect(decorations.every((d) => d.gradient == null), isTrue);
    });

    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets('360 dp ${locale.languageCode} : aucun débordement', (
        tester,
      ) async {
        if (locale == AppL10n.en) enableEnglish();
        await _pump(
          tester,
          ValueNotifier(TransportMode.plane),
          locale: locale,
          size: const Size(360, 800),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
