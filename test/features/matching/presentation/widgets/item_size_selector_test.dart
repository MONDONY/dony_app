import 'dart:ui' show Tristate;

import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/presentation/widgets/item_size_selector.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required ItemSize? selected,
  required ValueChanged<ItemSize?> onChanged,
  bool allowDeselect = true,
  String locale = 'fr',
  double width = 360,
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: ItemSizeSelector(
          sizes: ItemSize.values,
          selected: selected,
          onChanged: onChanged,
          allowDeselect: allowDeselect,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('affiche les quatre codes et leurs descriptions', (tester) async {
    await tester.pumpWidget(_host(selected: null, onChanged: (_) {}));

    for (final code in ['S', 'M', 'L', 'XL']) {
      expect(find.text(code), findsOneWidget);
    }
    expect(find.text('Sac'), findsOneWidget);
    expect(find.text('Carton'), findsOneWidget);
    expect(find.text('Valise, chaise'), findsOneWidget);
    expect(find.text('Meuble'), findsOneWidget);
  });

  testWidgets('tap sur L sélectionne L, second tap désélectionne', (
    tester,
  ) async {
    ItemSize? current;
    final calls = <ItemSize?>[];
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _host(
            selected: current,
            onChanged: (v) {
              calls.add(v);
              rebuild(() => current = v);
            },
          );
        },
      ),
    );

    await tester.tap(find.text('L'));
    await tester.pump();
    expect(calls, [ItemSize.l]);

    await tester.tap(find.text('L'));
    await tester.pump();
    expect(calls, [ItemSize.l, null]);
  });

  testWidgets('allowDeselect faux : le second tap ne désélectionne pas', (
    tester,
  ) async {
    final calls = <ItemSize?>[];
    await tester.pumpWidget(
      _host(selected: ItemSize.m, allowDeselect: false, onChanged: calls.add),
    );

    await tester.tap(find.text('M'));
    await tester.pump();

    expect(calls, isEmpty);
  });

  testWidgets('Semantics : seule la tuile choisie est sélectionnée', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(selected: ItemSize.xl, onChanged: (_) {}));

    final xl = tester.getSemantics(find.byKey(const Key('item-size-XL')));
    final s = tester.getSemantics(find.byKey(const Key('item-size-S')));
    expect(xl.flagsCollection.isSelected, Tristate.isTrue);
    expect(s.flagsCollection.isSelected, isNot(Tristate.isTrue));
    handle.dispose();
  });

  testWidgets('la tuile choisie a une bordure primaire unie', (tester) async {
    await tester.pumpWidget(_host(selected: ItemSize.m, onChanged: (_) {}));

    final primary = Theme.of(
      tester.element(find.byType(ItemSizeSelector)),
    ).colorScheme.primary;
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('item-size-M')),
        matching: find.byType(Container),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.color, primary);
    expect(decoration.gradient, isNull);
  });

  for (final locale in ['fr', 'en']) {
    testWidgets('360 dp $locale : quatre tuiles sans débordement', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(locale: locale, selected: ItemSize.l, onChanged: (_) {}),
      );

      expect(tester.takeException(), isNull);
      final tops = <double>{
        for (final code in ['S', 'M', 'L', 'XL'])
          tester.getTopLeft(find.byKey(Key('item-size-$code'))).dy,
      };
      expect(
        tops.length,
        1,
        reason: 'les quatre tuiles tiennent sur une ligne',
      );
      final widths = <double>{
        for (final code in ['S', 'M', 'L', 'XL'])
          tester.getSize(find.byKey(Key('item-size-$code'))).width,
      };
      expect(widths.length, 1, reason: 'tuiles égales');
    });
  }
}
