import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('DonyPriceTag', () {
    testWidgets('affiche le libellé, l\'emoji et le prix', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyPriceTag(label: 'Téléphone', emoji: '📱', price: '12,60 €'),
        ),
      );

      expect(find.text('Téléphone'), findsOneWidget);
      expect(find.text('📱'), findsOneWidget);
      expect(find.text('12,60 €'), findsOneWidget);
    });

    testWidgets('affiche la légende en taille normale', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyPriceTag(
            label: 'Téléphone',
            emoji: '📱',
            price: '12,60 €',
            caption: 'vous recevez 12,00 €',
          ),
        ),
      );

      expect(find.text('vous recevez 12,00 €'), findsOneWidget);
    });

    testWidgets('masque la légende en mode compact', (tester) async {
      // En aperçu, la place manque et le net du voyageur n'est pas
      // l'information utile : seul le prix payé compte.
      await tester.pumpWidget(
        _wrap(
          const DonyPriceTag(
            label: 'Téléphone',
            emoji: '📱',
            price: '12,60 €',
            caption: 'vous recevez 12,00 €',
            compact: true,
          ),
        ),
      );

      expect(find.text('vous recevez 12,00 €'), findsNothing);
      expect(find.text('Téléphone'), findsOneWidget);
    });

    testWidgets('déclenche onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          DonyPriceTag(
            label: 'Téléphone',
            emoji: '📱',
            price: '12,60 €',
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Téléphone'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('sans onTap, l\'étiquette n\'est pas un bouton', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyPriceTag(label: 'Téléphone', emoji: '📱', price: '12,60 €'),
        ),
      );

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('affiche le trailing fourni', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyPriceTag(
            label: 'Téléphone',
            emoji: '📱',
            price: '12,60 €',
            trailing: Text('trailing'),
          ),
        ),
      );

      expect(find.text('trailing'), findsOneWidget);
    });

    testWidgets('annonce article et prix par défaut', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const DonyPriceTag(label: 'Téléphone', emoji: '📱', price: '12,60 €'),
        ),
      );

      expect(find.bySemanticsLabel('Téléphone, 12,60 €'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('semanticLabel remplace l\'annonce par défaut', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const DonyPriceTag(
            label: 'Téléphone',
            emoji: '📱',
            price: '12,60 €',
            semanticLabel: 'Téléphone, l\'expéditeur paie 12,60 €',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Téléphone, l\'expéditeur paie 12,60 €'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('se rend en mode sombre sans exception', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyPriceTag(
            label: 'Téléphone',
            emoji: '📱',
            price: '12,60 €',
            caption: 'vous recevez 12,00 €',
            highlighted: true,
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Téléphone'), findsOneWidget);
    });

    testWidgets('un libellé très long s\'ellipse sans déborder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 320,
            child: DonyPriceTag(
              label: 'Médicaments traditionnels et plantes séchées du pays',
              emoji: '🌿',
              price: '26,25 €',
              compact: true,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
