// Tests de couverture pour _shared_widgets.dart.
// Ce fichier couvre : CaFieldCard, CaFieldIcon, CaSectionCard, CaRowDivider,
// CaSectionLabel, CaInlineAddRow, CaRemovableChip, CaTimeRow, CaStepperHeader,
// CaStepNode, CaDateRow.
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });
  // ── CaFieldCard ──────────────────────────────────────────────────────────────
  group('CaFieldCard', () {
    testWidgets('se construit et affiche son enfant', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaFieldCard(child: Text('champ')),
      ));
      expect(find.text('champ'), findsOneWidget);
    });

    testWidgets('utilise un ClipRRect et un Container', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaFieldCard(child: SizedBox()),
      ));
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(Container), findsAtLeastNWidgets(1));
    });
  });

  // ── CaFieldIcon ──────────────────────────────────────────────────────────────
  group('CaFieldIcon', () {
    testWidgets('se construit avec une icône', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaFieldIcon(icon: Icons.search),
      ));
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('rend un Icon avec la taille 20', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaFieldIcon(icon: Icons.flight),
      ));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, 20);
    });
  });

  // ── CaSectionCard ─────────────────────────────────────────────────────────────
  group('CaSectionCard', () {
    testWidgets('se construit et affiche son enfant', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaSectionCard(child: Text('section')),
      ));
      expect(find.text('section'), findsOneWidget);
    });

    testWidgets('utilise un ClipRRect', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaSectionCard(child: SizedBox()),
      ));
      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });

  // ── CaRowDivider ─────────────────────────────────────────────────────────────
  group('CaRowDivider', () {
    testWidgets('se construit sans exception', (tester) async {
      await tester.pumpWidget(_wrap(const CaRowDivider()));
      expect(find.byType(CaRowDivider), findsOneWidget);
    });

    testWidgets('rend un Container de hauteur 0.5', (tester) async {
      await tester.pumpWidget(_wrap(const CaRowDivider()));
      final containers = tester.widgetList<Container>(find.byType(Container));
      // Le Container le plus interne a height: 0.5
      final dividerContainers = containers.where((c) {
        if (c.constraints == null) return false;
        final height = c.constraints!.maxHeight;
        return height == 0.5;
      }).toList();
      expect(dividerContainers, isNotEmpty);
    });
  });

  // ── CaSectionLabel ───────────────────────────────────────────────────────────
  group('CaSectionLabel', () {
    testWidgets('affiche le label sans icône', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaSectionLabel(label: 'Mon label'),
      ));
      expect(find.text('Mon label'), findsOneWidget);
    });

    testWidgets('affiche le label avec une icône', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaSectionLabel(label: 'Prix', icon: Icons.sell_rounded),
      ));
      expect(find.text('Prix'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('rend un Row quand icon est fourni', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaSectionLabel(label: 'Trajet', icon: Icons.flight),
      ));
      expect(find.byType(Row), findsWidgets);
    });
  });

  // ── CaInlineAddRow ───────────────────────────────────────────────────────────
  group('CaInlineAddRow', () {
    testWidgets('se construit avec un hint', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(_wrap(
        CaInlineAddRow(
          controller: ctrl,
          hint: 'Ajouter…',
          onAdd: () {},
        ),
      ));
      expect(find.byType(TextField), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('le bouton + appelle onAdd', (tester) async {
      final ctrl = TextEditingController(text: 'test');
      var called = false;
      await tester.pumpWidget(_wrap(
        CaInlineAddRow(
          controller: ctrl,
          hint: 'Ajouter…',
          onAdd: () => called = true,
        ),
      ));
      // Le GestureDetector autour du cercle + (bouton add)
      final gesture = find.byType(GestureDetector);
      await tester.tap(gesture.last);
      await tester.pump();
      expect(called, isTrue);
      ctrl.dispose();
    });

    testWidgets('soumission via le clavier déclenche onAdd', (tester) async {
      final ctrl = TextEditingController();
      var called = false;
      await tester.pumpWidget(_wrap(
        CaInlineAddRow(
          controller: ctrl,
          hint: 'Type here',
          onAdd: () => called = true,
        ),
      ));
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(called, isTrue);
      ctrl.dispose();
    });

    testWidgets('accentColor est utilisée pour colorier le bouton (défaut primary)',
        (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(_wrap(
        CaInlineAddRow(
          controller: ctrl,
          hint: 'hint',
          onAdd: () {},
          accentColor: Colors.red,
        ),
      ));
      // La décoration du Container bouton doit utiliser la couleur passée
      final containers = tester.widgetList<Container>(find.byType(Container)).toList();
      final coloredContainers = containers.where((c) {
        final deco = c.decoration;
        if (deco is BoxDecoration) {
          return deco.color == Colors.red;
        }
        return false;
      }).toList();
      expect(coloredContainers, isNotEmpty);
      ctrl.dispose();
    });
  });

  // ── CaRemovableChip ──────────────────────────────────────────────────────────
  group('CaRemovableChip', () {
    testWidgets('affiche le label', (tester) async {
      await tester.pumpWidget(_wrap(
        CaRemovableChip(
          label: 'Vêtements',
          accentColor: Colors.blue,
          onRemove: () {},
        ),
      ));
      expect(find.text('Vêtements'), findsOneWidget);
    });

    testWidgets('onRemove est appelé quand on tape sur la croix', (tester) async {
      var removed = false;
      await tester.pumpWidget(_wrap(
        CaRemovableChip(
          label: 'Médicaments',
          accentColor: Colors.green,
          onRemove: () => removed = true,
        ),
      ));
      // La croix est rendue par un GestureDetector
      final gesture = find.byType(GestureDetector);
      await tester.tap(gesture.first);
      await tester.pump();
      expect(removed, isTrue);
    });

    testWidgets('affiche une icône de fermeture', (tester) async {
      await tester.pumpWidget(_wrap(
        CaRemovableChip(
          label: 'Test',
          accentColor: Colors.purple,
          onRemove: () {},
        ),
      ));
      // CaRemovableChip rend désormais un DonyIcon('x') SVG, pas un Icon Material.
      expect(find.byType(DonyIcon), findsOneWidget);
    });
  });

  // ── CaTimeRow ────────────────────────────────────────────────────────────────
  group('CaTimeRow', () {
    testWidgets('affiche le placeholder départ quand time est null', (tester) async {
      await tester.pumpWidget(_wrap(
        CaTimeRow(
          isDeparture: true,
          time: null,
          onTap: () {},
        ),
      ));
      expect(find.text('Heure de départ (optionnel)'), findsOneWidget);
    });

    testWidgets('affiche le placeholder arrivée quand time est null et isDeparture=false',
        (tester) async {
      await tester.pumpWidget(_wrap(
        CaTimeRow(
          isDeparture: false,
          time: null,
          onTap: () {},
        ),
      ));
      expect(find.text("Heure d'arrivée (optionnel)"), findsOneWidget);
    });

    testWidgets('affiche l\'heure formatée quand time est fourni', (tester) async {
      await tester.pumpWidget(_wrap(
        CaTimeRow(
          isDeparture: true,
          time: const TimeOfDay(hour: 9, minute: 30),
          onTap: () {},
        ),
      ));
      expect(find.text('09:30'), findsOneWidget);
    });

    testWidgets('onTap est appelé au tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        CaTimeRow(
          isDeparture: true,
          time: null,
          onTap: () => tapped = true,
        ),
      ));
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('onClear est appelé quand time est fourni et onClear est tapé',
        (tester) async {
      var cleared = false;
      await tester.pumpWidget(_wrap(
        CaTimeRow(
          isDeparture: true,
          time: const TimeOfDay(hour: 10, minute: 0),
          onTap: () {},
          onClear: () => cleared = true,
        ),
      ));
      // La croix (close_rounded) est rendue — on la tape directement
      final closeIconFinder = find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'x',
      );
      expect(closeIconFinder, findsOneWidget);
      await tester.tap(closeIconFinder);
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('affiche une flèche (chevron) quand time est null', (tester) async {
      await tester.pumpWidget(_wrap(
        CaTimeRow(
          isDeparture: false,
          time: null,
          onTap: () {},
        ),
      ));
      // La flèche est Icons.chevron_right_rounded
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'chevron-right',
        ),
        findsOneWidget,
      );
    });
  });

  // ── CaStepperHeader ──────────────────────────────────────────────────────────
  group('CaStepperHeader', () {
    testWidgets('affiche les 3 labels de pas', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaStepperHeader(currentStep: 0, totalSteps: 3),
      ));
      await tester.pump();
      expect(find.text('Trajet'), findsOneWidget);
      expect(find.text('Lieux & capacité'), findsOneWidget);
      expect(find.text('Prix & conditions'), findsOneWidget);
    });

    testWidgets('affiche la coche (✓) sur les étapes complètes', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaStepperHeader(currentStep: 2, totalSteps: 3),
      ));
      await tester.pump();
      // Les pas 0 et 1 sont marqués ✓
      expect(find.textContaining('✓'), findsNWidgets(2));
    });

    testWidgets('affiche les CaStepNode', (tester) async {
      await tester.pumpWidget(_wrap(
        const CaStepperHeader(currentStep: 1, totalSteps: 3),
      ));
      await tester.pump();
      expect(find.byType(CaStepNode), findsNWidgets(3));
    });
  });

  // ── CaStepNode ───────────────────────────────────────────────────────────────
  group('CaStepNode', () {
    testWidgets('affiche le numéro quand le nœud n\'est ni actif ni terminé',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const CaStepNode(index: 2, currentStep: 0),
      ));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('affiche une icône check quand le nœud est terminé (index < currentStep)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const CaStepNode(index: 0, currentStep: 2),
      ));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'check',
        ),
        findsOneWidget,
      );
    });

    testWidgets('le nœud actif (index == currentStep) rend un AnimatedContainer',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const CaStepNode(index: 1, currentStep: 1),
      ));
      await tester.pump();
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });
  });

  // ── CaDateRow ────────────────────────────────────────────────────────────────
  group('CaDateRow', () {
    testWidgets('affiche le placeholder quand date est null', (tester) async {
      await tester.pumpWidget(_wrap(
        CaDateRow(date: null, onTap: () {}),
      ));
      expect(find.text('Date de départ'), findsOneWidget);
    });

    testWidgets('affiche la date formatée quand date est fournie', (tester) async {
      await tester.pumpWidget(_wrap(
        CaDateRow(
          date: DateTime(2026, 8, 15),
          onTap: () {},
        ),
      ));
      // Le texte de date est présent (format fr "sam. 15 août 2026" ou similaire)
      // On vérifie juste que le texte date n'est PAS le placeholder
      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      final hasDateText = textWidgets.any((t) {
        final data = t.data ?? '';
        return data.contains('2026') || data.contains('août') || data.contains('15');
      });
      expect(hasDateText, isTrue, reason: 'La date 2026-08-15 doit être affichée');
    });

    testWidgets('onTap est appelé au tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        CaDateRow(date: null, onTap: () => tapped = true),
      ));
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('affiche une icône calendrier', (tester) async {
      await tester.pumpWidget(_wrap(
        CaDateRow(date: null, onTap: () {}),
      ));
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'calendar',
        ),
        findsOneWidget,
      );
    });

    testWidgets('affiche une flèche (chevron_right) à droite', (tester) async {
      await tester.pumpWidget(_wrap(
        CaDateRow(date: null, onTap: () {}),
      ));
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'chevron-right',
        ),
        findsOneWidget,
      );
    });
  });
}
