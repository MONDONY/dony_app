import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mesure la zone réellement tappable et non le visuel : c'est la zone qui
/// reçoit le doigt, et c'est elle seule qui doit atteindre le minimum. Un
/// composant peut rester fin à l'écran tout en étant facile à viser.
Future<void> expectTapTarget(
  WidgetTester tester,
  String label,
  Widget child, {
  required Finder tappable,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
  final size = tester.getSize(tappable.first);
  expect(
    size.height,
    greaterThanOrEqualTo(kDonyMinTapTarget),
    reason: '$label : hauteur ${size.height}, minimum $kDonyMinTapTarget',
  );
  expect(
    size.width,
    greaterThanOrEqualTo(kDonyMinTapTarget),
    reason: '$label : largeur ${size.width}, minimum $kDonyMinTapTarget',
  );
}

void main() {
  testWidgets('DonyChip est visable au pouce', (tester) async {
    await expectTapTarget(
      tester,
      'DonyChip',
      DonyChip(label: 'Paris', selected: false, onTap: () {}),
      tappable: find.byType(GestureDetector),
    );
  });

  testWidgets('la pastille du DonyChip garde sa taille visuelle', (
    tester,
  ) async {
    // La correction agrandit la zone tappable, pas le dessin. Si la pastille
    // grossissait, tous les filtres de recherche doubleraient de hauteur.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: DonyChip(label: 'Paris', selected: false, onTap: () {}),
          ),
        ),
      ),
    );
    final pastille = tester.getSize(find.byType(AnimatedContainer).first);
    expect(
      pastille.height,
      lessThan(kDonyMinTapTarget),
      reason: 'la pastille doit rester plus fine que sa zone tappable',
    );
  });

  testWidgets('DonyChip reste cliquable dans sa marge transparente', (
    tester,
  ) async {
    // `HitTestBehavior.opaque` est le cœur de la correction : sans lui, la
    // marge ajoutée serait visuellement là mais ne recevrait aucun tap.
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: DonyChip(
              label: 'Paris',
              selected: false,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    final zone = tester.getRect(find.byType(GestureDetector).first);
    // Un point dans la marge haute, au-dessus de la pastille dessinée.
    await tester.tapAt(Offset(zone.center.dx, zone.top + 2));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('FavoriteHeartButton est visable au pouce', (tester) async {
    await expectTapTarget(
      tester,
      'FavoriteHeartButton',
      FavoriteHeartButton(isFavorite: false, onToggle: () {}),
      tappable: find.byType(IconButton),
    );
  });

  testWidgets('une option de DonyRadioGroup est visable au pouce', (
    tester,
  ) async {
    await expectTapTarget(
      tester,
      'DonyRadioGroup',
      SizedBox(
        width: 360,
        child: DonyRadioGroup<int>(
          value: 1,
          onChanged: (_) {},
          options: const [
            DonyRadioOption(value: 1, label: 'Un'),
            DonyRadioOption(value: 2, label: 'Deux'),
          ],
        ),
      ),
      tappable: find.byType(InkWell),
    );
  });

  testWidgets('une ligne de DonyListTile est visable au pouce', (tester) async {
    await expectTapTarget(
      tester,
      'DonyListTile',
      SizedBox(
        width: 360,
        child: DonyListTile(label: 'Réglages', onTap: () {}),
      ),
      tappable: find.byType(InkWell),
    );
  });

  testWidgets('DonyBackCircle est visable au pouce', (tester) async {
    await expectTapTarget(
      tester,
      'DonyBackCircle',
      DonyBackCircle(onTap: () {}),
      tappable: find.byType(InkWell),
    );
  });
}
