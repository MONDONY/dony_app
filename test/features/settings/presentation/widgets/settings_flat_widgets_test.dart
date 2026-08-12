import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('SettingsFlatGroup affiche ses children sans bordure',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const SettingsFlatGroup(children: [Text('ligne A'), Text('ligne B')]),
    ));
    expect(find.text('ligne A'), findsOneWidget);
    expect(find.text('ligne B'), findsOneWidget);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(SettingsFlatGroup),
        matching: find.byType(Container),
      ).first,
    );
    final deco = container.decoration as BoxDecoration;
    expect(deco.border, isNull); // flat = pas de bordure
  });

  testWidgets('SettingsSectionHeader affiche le label', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsSectionHeader('SÉCURITÉ')));
    expect(find.text('SÉCURITÉ'), findsOneWidget);
  });

  testWidgets('SettingsSectionHeader applique une couleur custom',
      (tester) async {
    await tester.pumpWidget(
        _wrap(const SettingsSectionHeader('CRITIQUE', color: Color(0xFFE53935))));
    final txt = tester.widget<Text>(find.text('CRITIQUE'));
    expect(txt.style?.color, const Color(0xFFE53935));
  });
}
