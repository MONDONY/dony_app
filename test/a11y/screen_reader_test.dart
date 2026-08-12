import 'package:flutter/semantics.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('DonyFieldError', () {
    testWidgets('est annoncé comme région live', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const DonyFieldError(message: 'Ville obligatoire'));

      final node = tester.getSemantics(find.text('Ville obligatoire'));
      expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
      expect(node.label, contains('Ville obligatoire'));
      handle.dispose();
    });

    testWidgets('n\'annonce rien sans message', (tester) async {
      // Une région live vide serait annoncée à chaque reconstruction. Sans
      // message, le widget ne doit rien produire du tout.
      final handle = tester.ensureSemantics();
      await _pump(tester, const DonyFieldError(message: null));
      expect(tester.getSize(find.byType(DonyFieldError)), Size.zero);
      expect(
        find.descendant(
          of: find.byType(DonyFieldError),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('l\'icône d\'alerte n\'est pas annoncée en double', (
      tester,
    ) async {
      // L'icône redit ce que le message dit. Annoncée, elle ajouterait du
      // bruit sans information.
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const DonyFieldError(message: 'Date invalide', withIcon: true),
      );
      final node = tester.getSemantics(find.text('Date invalide'));
      expect(node.label, 'Date invalide');
      handle.dispose();
    });
  });

  group('DonyStatusBanner', () {
    testWidgets('est annoncé comme région live', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const DonyStatusBanner(
          message: 'Paiement confirmé',
          type: DonyStatusBannerType.success,
        ),
      );
      final node = tester.getSemantics(find.text('Paiement confirmé'));
      expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
      handle.dispose();
    });

    testWidgets('le bouton de fermeture porte un nom', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        DonyStatusBanner(
          message: 'Vérification en attente',
          type: DonyStatusBannerType.warning,
          onDismiss: () {},
        ),
      );
      expect(
        find.bySemanticsLabel('Fermer le message'),
        findsOneWidget,
        reason: 'un bouton à icône seule doit porter un nom accessible',
      );
      handle.dispose();
    });
  });

  group('DonyChip', () {
    testWidgets('annonce son état sélectionné', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        DonyChip(label: 'Paris', selected: true, onTap: () {}),
      );
      final node = tester.getSemantics(find.text('Paris'));
      expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      handle.dispose();
    });

    testWidgets('annonce son état non sélectionné', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        DonyChip(label: 'Lyon', selected: false, onTap: () {}),
      );
      final node = tester.getSemantics(find.text('Lyon'));
      expect(node.hasFlag(SemanticsFlag.isSelected), isFalse);
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      handle.dispose();
    });

    testWidgets('annonce qu\'il est désactivé', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        DonyChip(
          label: 'Marseille',
          selected: false,
          enabled: false,
          onTap: () {},
        ),
      );
      final node = tester.getSemantics(find.text('Marseille'));
      expect(node.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
      expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
      handle.dispose();
    });
  });
}
