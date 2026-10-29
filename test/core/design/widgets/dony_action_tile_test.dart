import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contraint réellement la largeur (un `MediaQueryData(size:)` seul ne touche
/// pas au layout : la surface de test garde ses 800 dp).
Widget _wrap(
  Widget child, {
  double width = 360,
  double textScale = 1.0,
  Locale locale = const Locale('fr'),
}) => MaterialApp(
  theme: AppTheme.light(),
  locale: locale,
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DonySpacing.md),
            child: child,
          ),
        ),
      ),
    ),
  ),
);

/// Demi-largeur d'une tuile à 360 dp : marge `md` de chaque côté et `md` entre
/// les deux colonnes.
const double _tileWidth = (360 - 3 * DonySpacing.md) / 2;

DonyActionTile _tile({
  Key? key,
  String label = 'Alertes',
  String? subtitle,
  Widget? badge,
  bool dot = false,
  VoidCallback? onTap,
}) => DonyActionTile(
  key: key,
  iconName: 'bell',
  label: label,
  subtitle: subtitle,
  badge: badge,
  showNotificationDot: dot,
  color: const Color(0xFF0B5FFF),
  onTap: onTap ?? () {},
);

void main() {
  group('DonyActionTile', () {
    // Sous-titre limité à 2 lignes par défaut ; une tuile qui porte une
    // échéance (date et heure) peut en demander 3 pour qu'elle reste entière.
    testWidgets('subtitleMaxLines : 2 par défaut, 3 sur demande', (
      tester,
    ) async {
      const long =
          'Drop-off before Tue, Nov 3 at 1:30 PM, then more words to wrap';
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: _tileWidth,
            child: _tile(subtitle: long),
          ),
        ),
      );
      expect(tester.widget<Text>(find.text(long)).maxLines, 2);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: _tileWidth,
            child: DonyActionTile(
              iconName: 'bell',
              label: 'Lieux',
              subtitle: long,
              subtitleMaxLines: 3,
              color: const Color(0xFF0B5FFF),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(tester.widget<Text>(find.text(long)).maxLines, 3);
    });

    testWidgets('renders label, subtitle and badge', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _tile(
            label: 'Prévenir Awa',
            subtitle: 'Code prêt',
            badge: const Text('2 / 3'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Prévenir Awa'), findsOneWidget);
      expect(find.text('Code prêt'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('omits subtitle and badge when absent', (tester) async {
      await tester.pumpWidget(_wrap(_tile()));
      await tester.pump();

      expect(find.text('Alertes'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('calls onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(_tile(onTap: () => taps++)));
      await tester.pump();

      await tester.tap(find.text('Alertes'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('reads title, badge and subtitle as one button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          _tile(
            key: const Key('tile'),
            label: 'Prévenir Awa',
            subtitle: 'Envoyer le lien de suivi',
            badge: const ToolStatusBadge(
              ready: true,
              label: 'Code prêt',
              semanticsLabel: 'Code prêt',
            ),
          ),
        ),
      );
      await tester.pump();

      final node = tester.getSemantics(find.byKey(const Key('tile')));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, contains('Prévenir Awa'));
      expect(node.label, contains('Code prêt'));
      expect(node.label, contains('Envoyer le lien de suivi'));
      // Un seul nœud pour la tuile : la description n'a pas le sien.
      expect(find.bySemanticsLabel('Envoyer le lien de suivi'), findsNothing);
      handle.dispose();
    });

    testWidgets('shows notification dot only when asked', (tester) async {
      await tester.pumpWidget(_wrap(_tile()));
      await tester.pump();
      expect(find.byKey(const Key('tool-tile-dot')), findsNothing);

      await tester.pumpWidget(_wrap(_tile(dot: true)));
      await tester.pump();
      expect(find.byKey(const Key('tool-tile-dot')), findsOneWidget);
    });
  });

  group('DonyActionTileGrid', () {
    testWidgets('puts two tiles per row and keeps an odd last tile at half '
        'width', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyActionTileGrid(
            tiles: [
              _tile(key: const Key('t1'), label: 'Un'),
              _tile(key: const Key('t2'), label: 'Deux'),
              _tile(key: const Key('t3'), label: 'Trois'),
            ],
          ),
        ),
      );
      await tester.pump();

      final t1 = tester.getRect(find.byKey(const Key('t1')));
      final t2 = tester.getRect(find.byKey(const Key('t2')));
      final t3 = tester.getRect(find.byKey(const Key('t3')));

      // Même ligne pour les deux premières, la troisième dessous.
      expect(t2.top, t1.top);
      expect(t3.top, greaterThan(t1.bottom));
      expect(t3.left, t1.left);
      // Largeur réelle de 360 dp : deux colonnes séparées par `md`.
      expect(t1.width, closeTo(_tileWidth, 0.5));
      // Demi-largeur : la dernière tuile ne s'étire pas.
      expect(t3.width, closeTo(t1.width, 0.5));
      expect(t2.left - t1.right, DonySpacing.md);
      expect(t3.top - t1.bottom, DonySpacing.md);
    });

    testWidgets('equalizes tile heights within a row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyActionTileGrid(
            tiles: [
              _tile(key: const Key('short'), label: 'Un'),
              _tile(
                key: const Key('tall'),
                label: 'Deux',
                subtitle: 'Une description assez longue pour passer à la ligne',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const Key('short'))).height,
        tester.getSize(find.byKey(const Key('tall'))).height,
      );
    });

    testWidgets('renders nothing visible for an empty list', (tester) async {
      await tester.pumpWidget(_wrap(const DonyActionTileGrid(tiles: [])));
      await tester.pump();

      expect(find.byType(DonyActionTile), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 360 dp with TextScaler 1.3 and a 40-character '
        'English label', (tester) async {
      const longLabel = 'Notify the recipient about the pickup ok';
      expect(longLabel.length, 40);

      await tester.pumpWidget(
        _wrap(
          DonyActionTileGrid(
            tiles: [
              _tile(
                key: const Key('long'),
                label: longLabel,
                subtitle: 'Tracking link and pickup code are ready to share',
                badge: const Text('Code ready'),
                dot: true,
              ),
              _tile(key: const Key('neighbour'), label: 'Short'),
              _tile(label: 'More details'),
            ],
          ),
          textScale: 1.3,
          locale: const Locale('en'),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      // La tuile est bien à demi-largeur de 360 dp, pas de la surface de test.
      final long = tester.getSize(find.byKey(const Key('long')));
      expect(long.width, closeTo(_tileWidth, 0.5));
      expect(
        tester.getSize(find.byKey(const Key('neighbour'))).width,
        long.width,
      );

      // Un libellé de 40 caractères à ce grand texte passe à la ligne ; il est
      // plafonné à deux lignes avec points de suspension (`maxLines: 2`), sans
      // jamais déborder de la tuile.
      final oneLine = tester.getSize(find.text('Short')).height;
      expect(tester.getSize(find.text(longLabel)).height, greaterThan(oneLine));
    });
  });
}
