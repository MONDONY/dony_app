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
    testWidgets('affiche le libellé court du mode courant', (tester) async {
      await tester.pumpWidget(wrap(
        A11yTristateRow(
          label: 'Contraste élevé',
          subtitle: 'Renforce le texte et les bordures',
          value: AccessibilityMode.system,
          sheetTitle: 'Contraste élevé',
          onChanged: (_) {},
        ),
      ));
      // Valeur de ligne = libellé court (a11yModeShortLabel), pas le libellé
      // long de la sheet : 'Suivre le téléphone' n'apparaît qu'une fois
      // ouverte (cf. test ci-dessous).
      expect(find.text('Automatique'), findsOneWidget);
      expect(find.text('Suivre le téléphone'), findsNothing);
      expect(find.text('Renforce le texte et les bordures'), findsOneWidget);
    });

    testWidgets('le tap ouvre la sheet avec les trois libellés longs',
        (tester) async {
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
      // La sheet est l'endroit où l'utilisateur choisit : les trois
      // libellés longs et explicites, pas les versions courtes de la ligne.
      // (La ligne d'origine, avec sa valeur courte 'Automatique', reste
      // montée sous la sheet modale : on ne peut pas asserter son absence,
      // seulement la présence des trois libellés longs dans la sheet.)
      expect(find.text('Suivre le téléphone'), findsOneWidget);
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
        'le libellé court le plus long tient sur une seule ligne à 100 % '
        'sur un écran étroit', (tester) async {
      // iPhone SE (3ᵉ génération) : 375 pt de large, l'écran le plus étroit
      // couramment ciblé. Padding + icône reproduits pour matcher l'usage
      // réel dans accessibility_settings_screen.dart (DonySpacing.lg de
      // chaque côté, iconAsset renseigné).
      //
      // Contrairement à l'ancien libellé long ('Suivre le téléphone', qui ne
      // tenait sur une ligne dans aucun scénario compatible avec 200 %),
      // 'Automatique' (132 px sans contrainte) tient bien sous
      // kA11yTristateTrailingMaxWidth (160 px) : voir son commentaire pour
      // le calcul complet. Ce test verrouille ce résultat mesuré.
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
              // 'system' produit 'Automatique', le plus long des trois
              // libellés courts de a11yModeShortLabel.
              value: AccessibilityMode.system,
              sheetTitle: 'Contraste élevé',
              onChanged: (_) {},
            ),
          ),
        ),
      ));

      // Hauteur d'une ligne pour ce style (mise en page sans contrainte de
      // largeur ne change pas la hauteur d'une ligne, seulement sa largeur).
      final textWidget = tester.widget<Text>(find.text('Automatique'));
      final singleLine = TextPainter(
        text: TextSpan(text: textWidget.data, style: textWidget.style),
        textDirection: TextDirection.ltr,
      )..layout();

      final actualHeight = tester.getSize(find.text('Automatique')).height;

      expect(
        actualHeight,
        moreOrLessEquals(singleLine.height, epsilon: 1.0),
        reason: '"Automatique" ne tient plus sur une seule ligne à 100 % '
            'sur un écran de 375 pt de large (hauteur rendue $actualHeight '
            'vs ${singleLine.height} attendu pour une ligne) ; '
            'kA11yTristateTrailingMaxWidth a été resserrée par erreur.',
      );
    });

    testWidgets(
        'le libellé court le plus long ne fait pas déborder la ligne à '
        '200 % sur un écran étroit', (tester) async {
      // Même écran que le test « 200 % sans débordement » de
      // accessibility_settings_screen_test.dart (360 x 800 logiques une
      // fois le zoom pris en compte), mais isolé sur ce seul widget pour
      // documenter précisément, dans la suite de tests de ce widget, que
      // kA11yTristateTrailingMaxWidth (160 px) ne réintroduit pas le
      // débordement d'origine.
      tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 @3.0
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
              child: A11yTristateRow(
                iconAsset: 'contrast',
                label: 'Contraste élevé',
                subtitle: 'Renforce le texte et les bordures',
                value: AccessibilityMode.system,
                sheetTitle: 'Contraste élevé',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('a11yModeLabel', () {
    test('traduit les trois modes', () {
      expect(a11yModeLabel(AccessibilityMode.system), 'Suivre le téléphone');
      expect(a11yModeLabel(AccessibilityMode.on), 'Toujours activé');
      expect(a11yModeLabel(AccessibilityMode.off), 'Toujours désactivé');
    });
  });

  group('a11yModeShortLabel', () {
    test('traduit les trois modes en un mot', () {
      expect(a11yModeShortLabel(AccessibilityMode.system), 'Automatique');
      expect(a11yModeShortLabel(AccessibilityMode.on), 'Activé');
      expect(a11yModeShortLabel(AccessibilityMode.off), 'Désactivé');
    });
  });
}
