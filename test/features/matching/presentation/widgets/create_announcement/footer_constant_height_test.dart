// P5 — Footer à hauteur constante entre les étapes
//
// Vérifie que la zone footer (Key('donyBottomSheetFooter')) a exactement la
// même hauteur à l'étape 0 (1 bouton) et aux étapes 1-2 (2 boutons côte à côte).
//
// Raison pour laquelle le footer est déjà stable :
//   - DonyButton a une hauteur fixe de 52px (GlowButton : AnimatedContainer
//     height:52 ; secondary/ghost : minimumSize Size.fromHeight(52)).
//   - Row([Expanded(btn1)]) == Row([Expanded(btn2), SizedBox, Expanded(btn3)])
//     en hauteur, car max(52) == max(52, 0, 52) == 52.
//   - Le padding du Container footer est identique quelle que soit l'étape.
//
// Ce test est un filet de régression : si quelqu'un modifie DonyButton,
// ajoute une condition dans le footer, ou change le padding, il détecte
// immédiatement la rupture de la hauteur constante.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Ouvre un DonyBottomSheet avec [stickyBottom], attend la fin des animations,
/// puis retourne la hauteur rendue du Container portant
/// Key('donyBottomSheetFooter').
Future<double> _footerHeight(
  WidgetTester tester,
  Widget stickyBottom,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-sheet'),
              onPressed: () => DonyBottomSheet.show(
                ctx,
                title: 'Test',
                stickyBottom: stickyBottom,
                child: const SizedBox(height: 100),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('open-sheet')));
  await tester.pumpAndSettle();

  final footerFinder = find.byKey(const Key('donyBottomSheetFooter'));
  expect(footerFinder, findsOneWidget, reason: 'Le footer doit être rendu');

  return tester.getSize(footerFinder).height;
}

// ── Fixtures footer ───────────────────────────────────────────────────────────

/// Étape 0 : un seul bouton « Continuer » pleine largeur.
Widget get _footerStep0 => DonyButton(
      label: 'Continuer',
      iconRight: DonyIcons.arrowRight,
      onPressed: () {},
    );

/// Étapes 1-2 : deux boutons côte à côte (Retour + Continuer).
Widget get _footerStep1 => Row(
      children: [
        Expanded(
          child: DonyButton(
            label: 'Retour',
            variant: DonyButtonVariant.secondary,
            icon: DonyIcons.back,
            onPressed: () {},
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: DonyButton(
            label: 'Continuer',
            iconRight: DonyIcons.arrowRight,
            onPressed: () {},
          ),
        ),
      ],
    );

/// Étape 3 : deux boutons côte à côte (Retour + Aperçu).
Widget get _footerStep2 => Row(
      children: [
        Expanded(
          child: DonyButton(
            label: 'Retour',
            variant: DonyButtonVariant.secondary,
            icon: DonyIcons.back,
            onPressed: () {},
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: DonyButton(
            label: 'Aperçu',
            iconRight: DonyIcons.arrowRight,
            onPressed: () {},
          ),
        ),
      ],
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Taille d'écran fixe pour des mesures reproductibles.
  setUp(() {});

  group('P5 — footer à hauteur constante entre les 3 étapes', () {
    testWidgets(
      'step 0 (1 bouton) et step 1 (2 boutons) ont le même footer height',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final h0 = await _footerHeight(tester, _footerStep0);

        await tester.pumpWidget(const SizedBox.shrink()); // reset widget tree
        await tester.pump();

        final h1 = await _footerHeight(tester, _footerStep1);

        expect(
          h0,
          equals(h1),
          reason:
              'Le footer doit avoir la même hauteur à l\'étape 0 ($h0 px) '
              'et à l\'étape 1 ($h1 px)',
        );
      },
    );

    testWidgets(
      'step 1 (2 boutons Retour+Continuer) et step 2 (2 boutons Retour+Aperçu) '
      'ont le même footer height',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final h1 = await _footerHeight(tester, _footerStep1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        final h2 = await _footerHeight(tester, _footerStep2);

        expect(
          h1,
          equals(h2),
          reason:
              'Le footer doit avoir la même hauteur à l\'étape 1 ($h1 px) '
              'et à l\'étape 2 ($h2 px)',
        );
      },
    );

    testWidgets(
      'DonyButton primary pleine largeur a une hauteur de 52 px',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DonyButton(
                  key: const Key('btn-primary'),
                  label: 'Continuer',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final size = tester.getSize(find.byKey(const Key('btn-primary')));
        expect(
          size.height,
          equals(52),
          reason: 'DonyButton primary doit avoir exactement 52 px de haut',
        );
      },
    );

    testWidgets(
      'DonyButton secondary pleine largeur a une hauteur de 52 px',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DonyButton(
                  key: const Key('btn-secondary'),
                  label: 'Retour',
                  variant: DonyButtonVariant.secondary,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final size = tester.getSize(find.byKey(const Key('btn-secondary')));
        expect(
          size.height,
          equals(52),
          reason: 'DonyButton secondary doit avoir exactement 52 px de haut',
        );
      },
    );
  });
}
