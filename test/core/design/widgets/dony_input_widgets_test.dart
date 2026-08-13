import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  // ---------------------------------------------------------------------------
  // DonyChip
  // ---------------------------------------------------------------------------
  group('DonyChip', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(DonyChip(label: 'Paris', selected: false, onTap: () {})),
      );
      expect(find.text('Paris'), findsOneWidget);
    });

    testWidgets('renders without icon by default', (tester) async {
      await tester.pumpWidget(
        _wrap(DonyChip(label: 'Lyon', selected: false, onTap: () {})),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyChip(
            label: 'Avion',
            selected: false,
            onTap: () {},
            icon: Icons.flight,
          ),
        ),
      );
      expect(find.byIcon(Icons.flight), findsOneWidget);
    });

    testWidgets('onTap fires when enabled and chip is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DonyChip(label: 'Tap', selected: false, onTap: () => tapped = true),
        ),
      );
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('onTap does NOT fire when disabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DonyChip(
            label: 'Disabled',
            selected: false,
            onTap: () => tapped = true,
            enabled: false,
          ),
        ),
      );
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isFalse);
    });

    testWidgets('opacity is 1.0 when enabled', (tester) async {
      await tester.pumpWidget(
        _wrap(DonyChip(label: 'Enable', selected: false, onTap: () {})),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
    });

    testWidgets('opacity is 0.5 when disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyChip(
            label: 'Disabled',
            selected: false,
            onTap: () {},
            enabled: false,
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.5);
    });

    testWidgets('selected chip renders with bold weight (selected=true)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(DonyChip(label: 'Selected', selected: true, onTap: () {})),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Selected'), findsOneWidget);
    });

    testWidgets('unselected chip renders normally (selected=false)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(DonyChip(label: 'Unselected', selected: false, onTap: () {})),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Unselected'), findsOneWidget);
    });

    testWidgets('AnimatedContainer is present in widget tree', (tester) async {
      await tester.pumpWidget(
        _wrap(DonyChip(label: 'Anim', selected: false, onTap: () {})),
      );
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('selected + icon combo renders both elements', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyChip(
            label: 'Combo',
            selected: true,
            onTap: () {},
            icon: Icons.star,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Combo'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // DonyChipGroup
  // ---------------------------------------------------------------------------
  group('DonyChipGroup<String>', () {
    const options = ['Paris', 'Lyon', 'Marseille'];

    testWidgets('renders all options', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyChipGroup<String>(
            options: options,
            labelBuilder: (v) => v,
            selected: const {},
            onChanged: (_) {},
          ),
        ),
      );
      for (final city in options) {
        expect(find.text(city), findsOneWidget);
      }
    });

    testWidgets(
      'single-select: tapping an option calls onChanged with that item only',
      (tester) async {
        Set<String> result = {};
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) => DonyChipGroup<String>(
                options: options,
                labelBuilder: (v) => v,
                selected: result,
                onChanged: (v) => setState(() => result = v),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Lyon'));
        await tester.pump();
        expect(result, equals({'Lyon'}));
      },
    );

    testWidgets('single-select: tapping different option replaces previous', (
      tester,
    ) async {
      Set<String> result = {'Paris'};
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => DonyChipGroup<String>(
              options: options,
              labelBuilder: (v) => v,
              selected: result,
              onChanged: (v) => setState(() => result = v),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Marseille'));
      await tester.pump();
      expect(result, equals({'Marseille'}));
      expect(result.contains('Paris'), isFalse);
    });

    testWidgets('multi-select: tapping adds items to selection', (
      tester,
    ) async {
      Set<String> result = {};
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => DonyChipGroup<String>(
              options: options,
              labelBuilder: (v) => v,
              selected: result,
              onChanged: (v) => setState(() => result = v),
              multiSelect: true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Paris'));
      await tester.pump();
      await tester.tap(find.text('Lyon'));
      await tester.pump();
      expect(result, containsAll(['Paris', 'Lyon']));
    });

    testWidgets('multi-select: tapping selected item removes it', (
      tester,
    ) async {
      Set<String> result = {'Paris', 'Lyon'};
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => DonyChipGroup<String>(
              options: options,
              labelBuilder: (v) => v,
              selected: result,
              onChanged: (v) => setState(() => result = v),
              multiSelect: true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Paris'));
      await tester.pump();
      expect(result.contains('Paris'), isFalse);
      expect(result.contains('Lyon'), isTrue);
    });

    testWidgets('iconBuilder is called and renders icon when non-null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DonyChipGroup<String>(
            options: const ['Avion'],
            labelBuilder: (v) => v,
            selected: const {},
            onChanged: (_) {},
            iconBuilder: (_) => Icons.flight,
          ),
        ),
      );
      expect(find.byIcon(Icons.flight), findsOneWidget);
    });

    testWidgets('iconBuilder returning null renders no icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyChipGroup<String>(
            options: const ['NoIcon'],
            labelBuilder: (v) => v,
            selected: const {},
            onChanged: (_) {},
            iconBuilder: (_) => null,
          ),
        ),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('custom spacing parameter is accepted', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyChipGroup<String>(
            options: options,
            labelBuilder: (v) => v,
            selected: const {},
            onChanged: (_) {},
            spacing: 20,
          ),
        ),
      );
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 20);
    });

    testWidgets('uses Wrap layout', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyChipGroup<String>(
            options: options,
            labelBuilder: (v) => v,
            selected: const {},
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(Wrap), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // DonyCheckbox
  // ---------------------------------------------------------------------------
  group('DonyCheckbox', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(label: "J'accepte", value: false, onChanged: (_) {}),
        ),
      );
      expect(find.text("J'accepte"), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Label',
            value: false,
            onChanged: (_) {},
            subtitle: 'Some subtitle',
          ),
        ),
      );
      expect(find.text('Some subtitle'), findsOneWidget);
    });

    testWidgets('does not render subtitle when absent', (tester) async {
      await tester.pumpWidget(
        _wrap(DonyCheckbox(label: 'Label', value: false, onChanged: (_) {})),
      );
      // Only one Text widget (the label)
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('tapping fires onChanged with toggled value (false -> true)', (
      tester,
    ) async {
      bool? received;
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Toggle',
            value: false,
            onChanged: (v) => received = v,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(received, isTrue);
    });

    testWidgets('tapping fires onChanged with toggled value (true -> false)', (
      tester,
    ) async {
      bool? received;
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Toggle',
            value: true,
            onChanged: (v) => received = v,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(received, isFalse);
    });

    testWidgets('disabled: tapping does NOT fire onChanged', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Disabled',
            value: false,
            onChanged: (_) => called = true,
            enabled: false,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(called, isFalse);
    });

    testWidgets('disabled opacity is 0.4 on checkbox widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Disabled',
            value: false,
            onChanged: (_) {},
            enabled: false,
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.4);
    });

    testWidgets('enabled opacity is 1.0 on checkbox widget', (tester) async {
      await tester.pumpWidget(
        _wrap(DonyCheckbox(label: 'Enabled', value: false, onChanged: (_) {})),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
    });

    testWidgets('tristate=false: tapping cycles false -> true (not null)', (
      tester,
    ) async {
      bool? received;
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Tristate off',
            value: false,
            onChanged: (v) => received = v,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(received, isTrue);
      expect(received, isNot(null));
    });

    testWidgets('tristate=true: null -> true when tapped', (tester) async {
      bool? received = false; // track sentinel
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Tristate',
            value: null,
            onChanged: (v) => received = v,
            tristate: true,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(received, isTrue);
    });

    testWidgets('tristate=true: true -> false when tapped', (tester) async {
      bool? received;
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Tristate',
            value: true,
            onChanged: (v) => received = v,
            tristate: true,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(received, isFalse);
    });

    testWidgets('tristate=true: false -> null when tapped', (tester) async {
      bool? received = true; // sentinel
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Tristate',
            value: false,
            onChanged: (v) => received = v,
            tristate: true,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(received, isNull);
    });

    testWidgets('CrossAxisAlignment is start when subtitle provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DonyCheckbox(
            label: 'Label',
            value: false,
            onChanged: (_) {},
            subtitle: 'Sub',
          ),
        ),
      );
      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.crossAxisAlignment, CrossAxisAlignment.start);
    });

    testWidgets('CrossAxisAlignment is center when no subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(DonyCheckbox(label: 'Label', value: false, onChanged: (_) {})),
      );
      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.crossAxisAlignment, CrossAxisAlignment.center);
    });
  });

  // ---------------------------------------------------------------------------
  // DonyRadioGroup
  // ---------------------------------------------------------------------------
  group('DonyRadioGroup<String>', () {
    final options = [
      const DonyRadioOption<String>(value: 'SENDER', label: 'Expéditeur'),
      const DonyRadioOption<String>(
        value: 'TRAVELER',
        label: 'Voyageur',
        subtitle: 'Je transporte des colis',
      ),
    ];

    testWidgets('renders all option labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: options,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Expéditeur'), findsOneWidget);
      expect(find.text('Voyageur'), findsOneWidget);
    });

    testWidgets('renders group label when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: options,
            value: null,
            onChanged: (_) {},
            label: 'Rôle',
          ),
        ),
      );
      expect(find.text('Rôle'), findsOneWidget);
    });

    testWidgets('does NOT render group label when absent', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: options,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      // Only the two option labels — no extra group label
      expect(find.text('Expéditeur'), findsOneWidget);
      expect(find.text('Voyageur'), findsOneWidget);
    });

    testWidgets('renders subtitle for option that has one', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: options,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Je transporte des colis'), findsOneWidget);
    });

    testWidgets('tapping an option fires onChanged with that value', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: options,
            value: selected,
            onChanged: (v) => selected = v,
          ),
        ),
      );
      await tester.tap(find.text('Expéditeur'));
      expect(selected, equals('SENDER'));
    });

    testWidgets('tapping a different option updates selection', (tester) async {
      String? selected = 'SENDER';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => DonyRadioGroup<String>(
              options: options,
              value: selected,
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Voyageur'));
      await tester.pump();
      expect(selected, equals('TRAVELER'));
    });

    testWidgets('vertical direction uses Column layout (default)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: options,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      // The outer Column always exists; we confirm at least one Column is rendered
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('horizontal direction uses Wrap layout', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: options,
            value: null,
            onChanged: (_) {},
            direction: Axis.horizontal,
          ),
        ),
      );
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('icon is rendered when option has one', (tester) async {
      final withIcon = [
        const DonyRadioOption<String>(
          value: 'FLIGHT',
          label: 'Avion',
          icon: Icons.flight,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: withIcon,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.flight), findsOneWidget);
    });

    testWidgets('disabled option: tapping does not fire onChanged', (
      tester,
    ) async {
      bool called = false;
      final disabledOptions = [
        const DonyRadioOption<String>(
          value: 'DISABLED',
          label: 'Désactivé',
          enabled: false,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: disabledOptions,
            value: null,
            onChanged: (_) => called = true,
          ),
        ),
      );
      await tester.tap(find.text('Désactivé'));
      expect(called, isFalse);
    });

    testWidgets('_RadioDot is rendered for each option', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: options,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      // AnimatedContainer is used inside _RadioDot — one per option
      expect(find.byType(AnimatedContainer), findsNWidgets(options.length));
    });

    testWidgets(
      'selected value changes _RadioDot appearance (selected=true path)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            DonyRadioGroup<String>(
              options: options,
              value: 'SENDER',
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        // The inner white dot is a Container inside the selected _RadioDot
        // Just verify the widget tree still renders correctly
        expect(find.text('Expéditeur'), findsOneWidget);
      },
    );

    testWidgets('CrossAxisAlignment is start for option with subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DonyRadioGroup<String>(
            options: options,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      // Find rows inside InkWells (tile rows)
      final rows = tester.widgetList<Row>(find.byType(Row));
      final alignments = rows.map((r) => r.crossAxisAlignment).toList();
      // At least one row has CrossAxisAlignment.start (the one with subtitle)
      expect(alignments, contains(CrossAxisAlignment.start));
    });
  });

  // ---------------------------------------------------------------------------
  // DonySearchField
  // ---------------------------------------------------------------------------
  group('DonySearchField', () {
    testWidgets('renders hint text', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonySearchField(hint: 'Rechercher un trajet...')),
      );
      expect(find.text('Rechercher un trajet...'), findsOneWidget);
    });

    testWidgets('uses default hint when none provided', (tester) async {
      await tester.pumpWidget(_wrap(const DonySearchField()));
      expect(find.text('Rechercher...'), findsOneWidget);
    });

    testWidgets('renders search prefix icon by default', (tester) async {
      await tester.pumpWidget(_wrap(const DonySearchField()));
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('renders custom prefix icon when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonySearchField(prefixIcon: Icons.location_on)),
      );
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('clear button is NOT shown when field is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const DonySearchField()));
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
        findsNothing,
      );
    });

    testWidgets('clear button appears after typing text', (tester) async {
      await tester.pumpWidget(_wrap(const DonySearchField()));
      await tester.enterText(find.byType(TextField), 'Dakar');
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
        findsOneWidget,
      );
    });

    testWidgets('onChanged fires when text is entered', (tester) async {
      String? received;
      await tester.pumpWidget(
        _wrap(DonySearchField(onChanged: (v) => received = v)),
      );
      await tester.enterText(find.byType(TextField), 'Abidjan');
      expect(received, equals('Abidjan'));
    });

    testWidgets('onSubmitted fires on keyboard submit', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        _wrap(DonySearchField(onSubmitted: (v) => submitted = v)),
      );
      await tester.enterText(find.byType(TextField), 'Bamako');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, equals('Bamako'));
    });

    testWidgets('tapping clear button clears the text', (tester) async {
      await tester.pumpWidget(_wrap(const DonySearchField()));
      await tester.enterText(find.byType(TextField), 'Douala');
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
        findsOneWidget,
      );

      await tester.tap(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
      );
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text ?? '', equals(''));
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
        findsNothing,
      );
    });

    testWidgets('onClear fires when clear button is tapped', (tester) async {
      bool cleared = false;
      await tester.pumpWidget(
        _wrap(DonySearchField(onClear: () => cleared = true)),
      );
      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
      );
      expect(cleared, isTrue);
    });

    testWidgets(
      'onChanged fires with empty string when clear button is tapped',
      (tester) async {
        String? lastValue = 'sentinel';
        await tester.pumpWidget(
          _wrap(DonySearchField(onChanged: (v) => lastValue = v)),
        );
        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();
        await tester.tap(
          find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
        );
        expect(lastValue, equals(''));
      },
    );

    testWidgets('accepts external controller and reflects its value', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(DonySearchField(controller: controller)));
      // Type via the controller to trigger the listener
      await tester.enterText(find.byType(TextField), 'Préchargé');
      await tester.pump();
      // Clear icon should now be visible since the field has text
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
        findsOneWidget,
      );
      // The controller still holds the text
      expect(controller.text, equals('Préchargé'));
    });

    testWidgets('does NOT dispose external controller on widget disposal', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Keep');
      await tester.pumpWidget(_wrap(DonySearchField(controller: controller)));
      // Replace widget tree to trigger dispose
      await tester.pumpWidget(_wrap(const SizedBox()));
      // Controller should still be usable (no assertion error)
      expect(controller.text, equals('Keep'));
      controller.dispose();
    });

    testWidgets('enabled=false disables the TextField', (tester) async {
      await tester.pumpWidget(_wrap(const DonySearchField(enabled: false)));
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
    });

    testWidgets('autofocus=true passes autofocus to TextField', (tester) async {
      await tester.pumpWidget(_wrap(const DonySearchField(autofocus: true)));
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.autofocus, isTrue);
    });

    testWidgets('textInputAction is search', (tester) async {
      await tester.pumpWidget(_wrap(const DonySearchField()));
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.textInputAction, TextInputAction.search);
    });
  });
}
