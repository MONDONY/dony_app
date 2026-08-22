import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('DonyOnboardingGauge', () {
    testWidgets('le compteur ne compte que les étapes terminées', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyOnboardingGauge(
            segments: [
              DonyGaugeSegment.done,
              DonyGaugeSegment.done,
              DonyGaugeSegment.current,
              DonyGaugeSegment.todo,
              DonyGaugeSegment.todo,
            ],
            label: 'Identité',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 / 5 · Identité'), findsOneWidget);
    });

    testWidgets('un segment par étape', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyOnboardingGauge(
            segments: [
              DonyGaugeSegment.done,
              DonyGaugeSegment.current,
              DonyGaugeSegment.todo,
              DonyGaugeSegment.todo,
            ],
            label: 'Pays',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TweenAnimationBuilder<double>), findsNWidgets(4));

      // Verrouille le mapping état → remplissage : une étape passée doit
      // rester vide (0.0), pas se confondre avec « terminée » (1.0).
      final factors = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((w) => w.widthFactor)
          .toList();
      expect(factors, [1.0, 0.5, 0.0, 0.0]);
    });

    testWidgets('l\'information ne passe pas que par la couleur', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyOnboardingGauge(
            segments: [
              DonyGaugeSegment.done,
              DonyGaugeSegment.done,
              DonyGaugeSegment.current,
              DonyGaugeSegment.todo,
              DonyGaugeSegment.todo,
            ],
            label: 'Identité',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(DonyOnboardingGauge));
      expect(semantics.value, 'Étape 3 sur 5, 2 terminées');
      // Sans label, le lecteur d'écran annonce juste « 0 étape sur 5
      // terminée » sans dire de quoi il s'agit (revue finale du lot 2,
      // correction 5). Le label du `Text` visible se fusionne en dessous
      // (comportement standard de `Semantics(container: true)`), d'où le
      // `startsWith` plutôt qu'une égalité stricte.
      expect(semantics.label, startsWith('Progression de l\'inscription'));
    });

    testWidgets('sans étape en cours, la lecture porte sur le total atteint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyOnboardingGauge(
            segments: [DonyGaugeSegment.done, DonyGaugeSegment.todo],
            label: 'Parrainage',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(DonyOnboardingGauge));
      expect(semantics.value, '1 étape sur 2 terminée');
      expect(semantics.label, startsWith('Progression de l\'inscription'));
    });

    testWidgets('tient à 200 % de taille de texte sans déborder', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _wrap(
            const DonyOnboardingGauge(
              segments: [
                DonyGaugeSegment.done,
                DonyGaugeSegment.current,
                DonyGaugeSegment.todo,
                DonyGaugeSegment.todo,
                DonyGaugeSegment.todo,
              ],
              label: 'Confidentialité',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
