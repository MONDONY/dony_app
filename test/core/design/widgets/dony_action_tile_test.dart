import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DonySpacing.md),
        child: child,
      ),
    ),
  ),
);

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
                label: longLabel,
                subtitle: 'Tracking link and pickup code are ready to share',
                badge: const Text('Code ready'),
                dot: true,
              ),
              _tile(label: 'Parcel and recipient details'),
              _tile(label: 'More details'),
            ],
          ),
          textScale: 1.3,
          locale: const Locale('en'),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
