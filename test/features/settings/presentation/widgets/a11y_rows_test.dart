import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_slider_row.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_tristate_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('A11ySliderRow', () {
    testWidgets('affiche le pourcentage courant', (tester) async {
      await tester.pumpWidget(wrap(
        A11ySliderRow(value: 1.25, enabled: true, onChanged: (_) {}),
      ));
      expect(find.text('125 %'), findsOneWidget);
    });

    testWidgets('le curseur est désactivé quand enabled est faux',
        (tester) async {
      await tester.pumpWidget(wrap(
        A11ySliderRow(value: 1.0, enabled: false, onChanged: (_) {}),
      ));
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
    });

    testWidgets('le curseur remonte la nouvelle valeur', (tester) async {
      double? received;
      await tester.pumpWidget(wrap(
        A11ySliderRow(value: 1.0, enabled: true, onChanged: (v) => received = v),
      ));
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pump();
      expect(received, isNotNull);
      expect(received, greaterThan(1.0));
    });
  });

  group('A11yTristateRow', () {
    testWidgets('affiche le libellé du mode courant', (tester) async {
      await tester.pumpWidget(wrap(
        A11yTristateRow(
          label: 'Contraste élevé',
          subtitle: 'Renforce le texte et les bordures',
          value: AccessibilityMode.system,
          sheetTitle: 'Contraste élevé',
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Suivre le téléphone'), findsOneWidget);
      expect(find.text('Renforce le texte et les bordures'), findsOneWidget);
    });

    testWidgets('le tap ouvre la sheet avec les trois choix', (tester) async {
      await tester.pumpWidget(wrap(
        A11yTristateRow(
          label: 'Contraste élevé',
          subtitle: 'Renforce le texte et les bordures',
          value: AccessibilityMode.system,
          sheetTitle: 'Contraste élevé',
          onChanged: (_) {},
        ),
      ));
      await tester.tap(find.text('Contraste élevé').first);
      await tester.pumpAndSettle();
      expect(find.text('Toujours activé'), findsOneWidget);
      expect(find.text('Toujours désactivé'), findsOneWidget);
    });

    testWidgets('sélectionner un choix remonte la valeur et ferme la sheet',
        (tester) async {
      String? received;
      await tester.pumpWidget(wrap(
        A11yTristateRow(
          label: 'Contraste élevé',
          subtitle: 'Renforce le texte et les bordures',
          value: AccessibilityMode.system,
          sheetTitle: 'Contraste élevé',
          onChanged: (v) => received = v,
        ),
      ));
      await tester.tap(find.text('Contraste élevé').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toujours activé'));
      await tester.pumpAndSettle();
      expect(received, AccessibilityMode.on);
      expect(find.text('Toujours désactivé'), findsNothing);
    });
  });

  group('a11yModeLabel', () {
    test('traduit les trois modes', () {
      expect(a11yModeLabel(AccessibilityMode.system), 'Suivre le téléphone');
      expect(a11yModeLabel(AccessibilityMode.on), 'Toujours activé');
      expect(a11yModeLabel(AccessibilityMode.off), 'Toujours désactivé');
    });
  });
}
