// Tests de couverture pour _shared_widgets.dart.
// Ce fichier couvre : CaSectionCard, CaRowDivider, CaSectionLabel,
// CaStepperHeader, CaStepNode.
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  // ── CaSectionCard ─────────────────────────────────────────────────────────────
  group('CaSectionCard', () {
    testWidgets('se construit et affiche son enfant', (tester) async {
      await tester.pumpWidget(
        _wrap(const CaSectionCard(child: Text('section'))),
      );
      expect(find.text('section'), findsOneWidget);
    });

    testWidgets('utilise un ClipRRect', (tester) async {
      await tester.pumpWidget(_wrap(const CaSectionCard(child: SizedBox())));
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
      await tester.pumpWidget(_wrap(const CaSectionLabel(label: 'Mon label')));
      expect(find.text('Mon label'), findsOneWidget);
    });

    testWidgets('affiche le label avec une icône', (tester) async {
      await tester.pumpWidget(
        _wrap(const CaSectionLabel(label: 'Prix', icon: Icons.sell_rounded)),
      );
      expect(find.text('Prix'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('rend un Row quand icon est fourni', (tester) async {
      await tester.pumpWidget(
        _wrap(const CaSectionLabel(label: 'Trajet', icon: Icons.flight)),
      );
      expect(find.byType(Row), findsWidgets);
    });
  });

  // ── CaStepperHeader ──────────────────────────────────────────────────────────
  group('CaStepperHeader', () {
    testWidgets('affiche les 3 labels de pas', (tester) async {
      await tester.pumpWidget(
        _wrap(const CaStepperHeader(currentStep: 0, totalSteps: 3)),
      );
      await tester.pump();
      expect(find.text('Trajet'), findsOneWidget);
      expect(find.text('Lieux & capacité'), findsOneWidget);
      expect(find.text('Prix & conditions'), findsOneWidget);
    });

    testWidgets('affiche la coche (✓) sur les étapes complètes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CaStepperHeader(currentStep: 2, totalSteps: 3)),
      );
      await tester.pump();
      // Les pas 0 et 1 sont marqués ✓
      expect(find.textContaining('✓'), findsNWidgets(2));
    });

    testWidgets('affiche les CaStepNode', (tester) async {
      await tester.pumpWidget(
        _wrap(const CaStepperHeader(currentStep: 1, totalSteps: 3)),
      );
      await tester.pump();
      expect(find.byType(CaStepNode), findsNWidgets(3));
    });
  });

  // ── CaStepNode ───────────────────────────────────────────────────────────────
  group('CaStepNode', () {
    testWidgets('affiche le numéro quand le nœud n\'est ni actif ni terminé', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CaStepNode(index: 2, currentStep: 0)),
      );
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets(
      'affiche une icône check quand le nœud est terminé (index < currentStep)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const CaStepNode(index: 0, currentStep: 2)),
        );
        await tester.pump();
        expect(
          find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'check'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'le nœud actif (index == currentStep) rend un AnimatedContainer',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const CaStepNode(index: 1, currentStep: 1)),
        );
        await tester.pump();
        expect(find.byType(AnimatedContainer), findsOneWidget);
      },
    );
  });

  // ── Group: English (i18n) ─────────────────────────────────────────────────

  group('CaStepperHeader — English', () {
    testWidgets('les 3 labels de pas sont traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(const CaStepperHeader(currentStep: 0, totalSteps: 3)),
      );
      await tester.pump();
      expect(find.text('Trip'), findsOneWidget);
      expect(find.text('Places & capacity'), findsOneWidget);
      expect(find.text('Price & conditions'), findsOneWidget);
    });
  });
}
