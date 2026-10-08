import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _gradient = LinearGradient(
  colors: [DonyColors.ink800, DonyColors.blue700],
);

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

DonyNegoHeroCard _hero({
  int rounds = 2,
  int max = 5,
  String? warning,
  String? turnLabel,
  bool myTurn = false,
}) => DonyNegoHeroCard(
  gradient: _gradient,
  shadowColor: DonyColors.blue500,
  iconAsset: 'handshake',
  caption: 'PRIX ACTUEL',
  amount: '42,00 €',
  amountKey: const Key('amount'),
  badgeLabel: 'EN COURS',
  roundLabel: 'Tour $rounds sur $max',
  roundsCount: rounds,
  maxRounds: max,
  warning: warning,
  turnLabel: turnLabel,
  myTurn: myTurn,
);

/// Segments de la jauge des tours : barres de 4 px de haut.
Iterable<BoxDecoration> _segments(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .where((c) => c.constraints?.maxHeight == 4)
    .map((c) => c.decoration! as BoxDecoration);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('DonyNegoHeroCard', () {
    testWidgets('affiche légende, montant, pastille et libellé de tour', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hero()));

      expect(find.text('PRIX ACTUEL'), findsOneWidget);
      expect(find.byKey(const Key('amount')), findsOneWidget);
      expect(find.text('42,00 €'), findsOneWidget);
      expect(find.text('EN COURS'), findsOneWidget);
      expect(find.text('Tour 2 sur 5'), findsOneWidget);
    });

    testWidgets('la jauge compte autant de segments que de tours possibles', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hero(max: 6)));

      final segs = _segments(tester).toList();
      expect(segs, hasLength(6));
      expect(segs.where((d) => d.color == Colors.white), hasLength(2));
    });

    testWidgets('sans plafond connu, aucune jauge', (tester) async {
      await tester.pumpWidget(_wrap(_hero(max: 0)));

      expect(_segments(tester), isEmpty);
    });

    testWidgets('au-delà du plafond, la jauge reste pleine', (tester) async {
      await tester.pumpWidget(_wrap(_hero(rounds: 9, max: 3)));

      expect(
        _segments(tester).where((d) => d.color == Colors.white),
        hasLength(3),
      );
    });

    testWidgets('avertissement et pastille de tour optionnels', (tester) async {
      await tester.pumpWidget(_wrap(_hero()));
      expect(find.byKey(const Key('nego-hero-my-turn')), findsNothing);
      expect(find.byKey(const Key('nego-hero-their-turn')), findsNothing);

      await tester.pumpWidget(
        _wrap(
          _hero(
            warning: 'Dernier tour',
            turnLabel: 'À vous de jouer',
            myTurn: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Dernier tour'), findsOneWidget);
      expect(find.byKey(const Key('nego-hero-my-turn')), findsOneWidget);
      expect(find.text('À vous de jouer'), findsOneWidget);
    });

    testWidgets('tour de l autre : pastille translucide', (tester) async {
      await tester.pumpWidget(_wrap(_hero(turnLabel: 'Au tour de Awa')));

      final pill = tester.widget<Container>(
        find.byKey(const Key('nego-hero-their-turn')),
      );
      final deco = pill.decoration! as BoxDecoration;
      expect(deco.color, Colors.white.withValues(alpha: 0.14));
    });
  });

  group('DonyNegoBubble', () {
    testWidgets('mienne : fond primary, alignée à droite, heure affichée', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DonyNegoBubble(
            kindLabel: 'PROPOSITION',
            mine: true,
            priceText: '42,00 €',
            body: 'Bonjour',
            sentAt: DateTime(2026, 5, 11, 9, 51),
          ),
        ),
      );

      expect(find.text('PROPOSITION'), findsOneWidget);
      expect(find.text('42,00 €'), findsOneWidget);
      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.textContaining('9:51'), findsOneWidget);
      final align = tester.widget<Align>(
        find
            .descendant(
              of: find.byType(DonyNegoBubble),
              matching: find.byType(Align),
            )
            .first,
      );
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('reçue et mise en avant : pastille NOUVEAU, alignée à gauche', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyNegoBubble(
            kindLabel: 'CONTRE-OFFRE',
            mine: false,
            highlight: true,
          ),
        ),
      );

      expect(find.text('NOUVEAU'), findsOneWidget);
      final align = tester.widget<Align>(
        find
            .descendant(
              of: find.byType(DonyNegoBubble),
              matching: find.byType(Align),
            )
            .first,
      );
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('sans heure ni montant ni texte : seul le libellé reste', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DonyNegoBubble(kindLabel: 'REJETÉE', mine: false)),
      );

      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(texts, hasLength(1));
      expect(texts.single.data, 'REJETÉE');
    });

    testWidgets('la pastille NOUVEAU ne s affiche jamais sur ma bulle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyNegoBubble(kindLabel: 'X', mine: true, highlight: true),
        ),
      );

      expect(find.text('NOUVEAU'), findsNothing);
    });
  });
}
