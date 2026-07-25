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

    testWidgets(
        'le libellé de mode le plus long passe proprement sur deux lignes '
        'à 100 % sur un écran étroit, jamais plus', (tester) async {
      // iPhone SE (3ᵉ génération) : 375 pt de large, l'écran le plus étroit
      // couramment ciblé. Padding + icône reproduits pour matcher l'usage
      // réel dans accessibility_settings_screen.dart (DonySpacing.lg de
      // chaque côté, iconAsset renseigné).
      //
      // 'Suivre le téléphone' (228 px sans contrainte à 100 %) ne tient sur
      // une seule ligne dans aucun scénario qui évite aussi le débordement à
      // 200 % (cf. commentaire de kA11yTristateTrailingMaxWidth) : deux
      // lignes est le résultat attendu et assumé, pas une régression. Ce
      // test verrouille ce compromis à sa valeur actuelle (176) et détecte
      // un resserrement accidentel qui le ferait replier sur trois ou
      // quatre lignes.
      tester.view.physicalSize = const Size(1125, 2436); // 375 x 812 @3.0
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
            child: A11yTristateRow(
              iconAsset: 'contrast',
              label: 'Contraste élevé',
              subtitle: 'Renforce le texte et les bordures',
              // 'system' produit 'Suivre le téléphone', le plus long des
              // trois libellés de a11yModeLabel.
              value: AccessibilityMode.system,
              sheetTitle: 'Contraste élevé',
              onChanged: (_) {},
            ),
          ),
        ),
      ));

      // Hauteur d'une ligne pour ce style (mise en page sans contrainte de
      // largeur ne change pas la hauteur d'une ligne, seulement sa largeur).
      final textWidget = tester.widget<Text>(find.text('Suivre le téléphone'));
      final singleLine = TextPainter(
        text: TextSpan(text: textWidget.data, style: textWidget.style),
        textDirection: TextDirection.ltr,
      )..layout();

      final actualHeight =
          tester.getSize(find.text('Suivre le téléphone')).height;

      expect(
        actualHeight,
        moreOrLessEquals(singleLine.height * 2, epsilon: 1.0),
        reason: '"Suivre le téléphone" doit tenir sur exactement deux '
            'lignes à 100 % sur un écran de 375 pt de large (hauteur '
            'rendue $actualHeight vs ${singleLine.height} × 2 attendu). '
            'Si le résultat est ${singleLine.height} (une ligne), très bien, '
            'mettre à jour cette assertion et le commentaire de '
            'kA11yTristateTrailingMaxWidth. Si le résultat dépasse deux '
            'lignes, kA11yTristateTrailingMaxWidth a été resserrée par '
            'erreur.',
      );
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
