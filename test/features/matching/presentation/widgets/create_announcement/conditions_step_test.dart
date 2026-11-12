// Tests de ConditionsStep — section « Conditions » du formulaire « Publier un
// trajet » : ce que j'accepte, ce que je refuse, note aux expéditeurs.
//
// Le widget ne dépend d'aucun BLoC : il lit uniquement des ValueNotifier et des
// TextEditingController, créés ici dans le host.
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/conditions_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

Widget _host({
  ValueNotifier<Set<String>>? selectedContent,
  ValueNotifier<Set<String>>? customAccepted,
  ValueNotifier<Set<String>>? refusedTypes,
  TextEditingController? descriptionCtrl,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ConditionsStep(
          selectedContentNotifier:
              selectedContent ?? ValueNotifier<Set<String>>({}),
          customAcceptedNotifier:
              customAccepted ?? ValueNotifier<Set<String>>({}),
          refusedTypesNotifier: refusedTypes ?? ValueNotifier<Set<String>>({}),
          catalogLabelsNotifier: ValueNotifier<List<String>>(
            fallbackCatalog.map((c) => c.label).toList(),
          ),
          descriptionCtrl: descriptionCtrl ?? TextEditingController(),
          customAcceptedCtrl: TextEditingController(),
          refusedCtrl: TextEditingController(),
        ),
      ),
    ),
  );
}

/// Pompe le widget et draine les animations flutter_animate (delay ≤ 160 ms).
Future<void> _pump(
  WidgetTester tester, {
  ValueNotifier<Set<String>>? selectedContent,
  ValueNotifier<Set<String>>? customAccepted,
  ValueNotifier<Set<String>>? refusedTypes,
  TextEditingController? descriptionCtrl,
}) async {
  await tester.pumpWidget(
    _host(
      selectedContent: selectedContent,
      customAccepted: customAccepted,
      refusedTypes: refusedTypes,
      descriptionCtrl: descriptionCtrl,
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

void main() {
  group('ConditionsStep', () {
    testWidgets('se construit sans exception', (tester) async {
      await _pump(tester);
      expect(find.byType(ConditionsStep), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ── Section CE QUE J'ACCEPTE ──────────────────────────────────────────────

    testWidgets("label de section Ce que j'accepte est affiché", (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text("Ce que j'accepte"), findsOneWidget);
    });

    testWidgets(
      'focus sur le combobox « accepte » ouvre le catalogue complet (11 items) — pas une liste figée',
      (tester) async {
        await _pump(tester);
        // Même traitement que le combobox « refuse » : le champ est passé
        // sous la ligne de flottaison du viewport de test, il faut le remonter
        // avant de le taper.
        await tester.dragUntilVisible(
          find.byKey(const Key('accepted-content-field')),
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.tap(find.byKey(const Key('accepted-content-field')));
        await tester.pumpAndSettle();
        for (final category in fallbackCatalog) {
          expect(
            find.byKey(Key('accepted-content-item-${category.label}')),
            findsOneWidget,
            reason:
                'Item "${category.label}" doit être présent dans le combobox "Ce que j\'accepte"',
          );
        }
      },
    );

    testWidgets(
      'focus sur le combobox « refuse » ouvre aussi le catalogue complet',
      (tester) async {
        await _pump(tester);
        await tester.dragUntilVisible(
          find.byKey(const Key('refused-content-field')),
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.tap(find.byKey(const Key('refused-content-field')));
        await tester.pumpAndSettle();
        for (final category in fallbackCatalog) {
          expect(
            find.byKey(Key('refused-content-item-${category.label}')),
            findsOneWidget,
            reason:
                'Item "${category.label}" doit être présent dans le combobox "Ce que je refuse"',
          );
        }
      },
    );

    testWidgets(
      'saisie libre dans le combobox "Ce que j\'accepte" ajoute un élément custom',
      (tester) async {
        // Grand viewport pour que le champ + l'overlay tiennent entièrement
        // dans la fenêtre de test (évite un overlay tronqué en bas d'écran).
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _pump(tester);
        await tester.tap(find.byKey(const Key('accepted-content-field')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('accepted-content-field')),
          'Poissons',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('accepted-content-item-add')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('accepted-content-tag-Poissons')),
          findsOneWidget,
        );
      },
    );

    // ── Section CE QUE JE REFUSE ──────────────────────────────────────────────

    testWidgets('label de section Ce que je refuse est affiché', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Ce que je refuse'), findsOneWidget);
    });

    testWidgets(
      'saisie libre dans le combobox "Ce que je refuse" ajoute un élément custom',
      (tester) async {
        await _pump(tester);
        await tester.dragUntilVisible(
          find.byKey(const Key('refused-content-field')),
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.tap(find.byKey(const Key('refused-content-field')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('refused-content-field')),
          'Alcool',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('refused-content-item-add')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('refused-content-tag-Alcool')),
          findsOneWidget,
        );
      },
    );

    // ── Section NOTE AUX EXPÉDITEURS ─────────────────────────────────────────

    testWidgets('label de section Note aux expéditeurs est affiché', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Note aux expéditeurs'), findsOneWidget);
    });

    testWidgets('le champ note aux expéditeurs (TextField) est présent', (
      tester,
    ) async {
      await _pump(tester);
      // Le TextField de la note a un hintText caractéristique
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.maxLines == 4 && w.maxLength == 500,
        ),
        findsOneWidget,
      );
    });

    testWidgets('compteur de caractères 0/500 est affiché', (tester) async {
      await _pump(tester);
      expect(find.text('0/500'), findsOneWidget);
    });
  });

  group('ConditionsStep — combobox "Ce que j\'accepte"', () {
    testWidgets('tap sur un item du catalogue le sélectionne', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final selected = ValueNotifier<Set<String>>({});
      await _pump(tester, selectedContent: selected);

      await tester.tap(find.byKey(const Key('accepted-content-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('accepted-content-item-Vêtements & tissus')),
      );
      await tester.pumpAndSettle();

      expect(selected.value.contains('Vêtements & tissus'), isTrue);
    });

    testWidgets('re-tap sur un item déjà sélectionné le désélectionne', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final selected = ValueNotifier<Set<String>>({'Vêtements & tissus'});
      await _pump(tester, selectedContent: selected);

      await tester.tap(find.byKey(const Key('accepted-content-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('accepted-content-item-Vêtements & tissus')),
      );
      await tester.pumpAndSettle();

      expect(selected.value.contains('Vêtements & tissus'), isFalse);
    });

    testWidgets(
      'les tags custom sont affichés quand customAccepted est non vide',
      (tester) async {
        final customAccepted = ValueNotifier<Set<String>>({
          'Mon article custom',
        });
        await _pump(tester, customAccepted: customAccepted);

        expect(
          find.byKey(const Key('accepted-content-tag-Mon article custom')),
          findsOneWidget,
        );
      },
    );
  });

  group('ConditionsStep — combobox "Ce que je refuse"', () {
    testWidgets(
      'les tags de refus sont affichés quand refusedTypes est non vide',
      (tester) async {
        final refused = ValueNotifier<Set<String>>({'Liquides'});
        await _pump(tester, refusedTypes: refused);

        await tester.dragUntilVisible(
          find.byKey(const Key('refused-content-tag-Liquides')),
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        expect(
          find.byKey(const Key('refused-content-tag-Liquides')),
          findsOneWidget,
        );
      },
    );

    testWidgets('ajout via le combobox met à jour refusedTypesNotifier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final refused = ValueNotifier<Set<String>>({});
      await _pump(tester, refusedTypes: refused);

      await tester.dragUntilVisible(
        find.byKey(const Key('refused-content-field')),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.tap(find.byKey(const Key('refused-content-field')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('refused-content-field')),
        'Explosifs',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('refused-content-item-add')));
      await tester.pumpAndSettle();

      expect(refused.value.contains('Explosifs'), isTrue);
    });

    testWidgets('✕ sur un tag refused met à jour refusedTypesNotifier', (
      tester,
    ) async {
      final refused = ValueNotifier<Set<String>>({'Armes'});
      await _pump(tester, refusedTypes: refused);

      final tag = find.byKey(const Key('refused-content-tag-Armes'));
      await tester.dragUntilVisible(
        tag,
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(tag, findsOneWidget);

      await tester.tap(
        find.descendant(of: tag, matching: find.byType(GestureDetector)),
      );
      await tester.pumpAndSettle();

      expect(refused.value.contains('Armes'), isFalse);
    });
  });

  group(
    'ConditionsStep — combobox "Ce que j\'accepte" — ajout/suppression custom',
    () {
      testWidgets(
        'ajout via le combobox customAccepted met à jour le notifier',
        (tester) async {
          // Grand viewport pour que la section "Ce que j'accepte" soit dans le
          // rendu après l'ajout du toggle KG/MIXED qui pousse le contenu vers
          // le bas, et que l'overlay du combobox tienne dans la fenêtre.
          tester.view.physicalSize = const Size(800, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final customAccepted = ValueNotifier<Set<String>>({});
          await _pump(tester, customAccepted: customAccepted);

          await tester.tap(find.byKey(const Key('accepted-content-field')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('accepted-content-field')),
            'Bijoux',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('accepted-content-item-add')));
          await tester.pumpAndSettle();

          expect(customAccepted.value.contains('Bijoux'), isTrue);
        },
      );

      testWidgets(
        'suppression d\'un tag customAccepted met à jour le notifier',
        (tester) async {
          tester.view.physicalSize = const Size(800, 4000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final customAccepted = ValueNotifier<Set<String>>({'Bijoux'});
          await _pump(tester, customAccepted: customAccepted);

          final tag = find.byKey(const Key('accepted-content-tag-Bijoux'));
          expect(tag, findsOneWidget);

          await tester.tap(
            find.descendant(of: tag, matching: find.byType(GestureDetector)),
          );
          await tester.pumpAndSettle();

          expect(customAccepted.value.contains('Bijoux'), isFalse);
        },
      );
    },
  );

  group('ConditionsStep — note aux expéditeurs', () {
    testWidgets('le compteur de caractères est mis à jour en saisie', (
      tester,
    ) async {
      final descCtrl = TextEditingController();
      await _pump(tester, descriptionCtrl: descCtrl);

      // Initialement 0/500
      expect(find.text('0/500'), findsOneWidget);

      // Saisir "hello"
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.maxLines == 4 && w.maxLength == 500,
        ),
        'hello',
      );
      await tester.pump();

      // Maintenant 5/500
      expect(find.text('5/500'), findsOneWidget);
    });
  });

  group('ConditionsStep — English', () {
    testWidgets('titre de section "Ce que j\'accepte" traduit', (tester) async {
      useEnglish();
      await _pump(tester);
      expect(find.text('What I accept'), findsOneWidget);
    });
  });
}
