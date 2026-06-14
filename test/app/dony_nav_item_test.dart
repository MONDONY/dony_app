import 'package:dony/app/widgets/dony_nav_item.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Hôte minimal : DonyNavItem utilise Column(mainAxisSize.max) + Expanded,
  // il lui faut donc une hauteur bornée (comme dans la vraie bottom nav).
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(height: 80, width: 120, child: child)),
    ),
  );

  DonyNavItem buildItem({
    required int index,
    required int currentIndex,
    int badgeCount = 0,
    bool isPro = false,
    String? avatarUrl,
    String? avatarName,
    VoidCallback? onTap,
  }) => DonyNavItem(
    icon: Icons.person_rounded,
    outlinedIcon: Icons.person_outline_rounded,
    label: 'Moi',
    index: index,
    currentIndex: currentIndex,
    onTap: onTap ?? () {},
    badgeCount: badgeCount,
    isPro: isPro,
    avatarUrl: avatarUrl,
    avatarName: avatarName,
  );

  // Récupère la décoration de l'anneau (AnimatedContainer ancêtre du DonyAvatar).
  BoxDecoration ringDecoration(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.byType(DonyAvatar),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return container.decoration! as BoxDecoration;
  }

  group('DonyNavItem — mode avatar (avatarName renseigné)', () {
    testWidgets('affiche DonyAvatar, jamais l\'icône bonhomme', (tester) async {
      await tester.pumpWidget(
        host(buildItem(index: 4, currentIndex: 0, avatarName: 'Abou Diakite')),
      );

      expect(find.byType(DonyAvatar), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNothing);
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
      expect(find.text('Moi'), findsOneWidget);
    });

    testWidgets('anneau bleu quand actif', (tester) async {
      await tester.pumpWidget(
        host(buildItem(index: 4, currentIndex: 4, avatarName: 'Abou Diakite')),
      );

      final border = ringDecoration(tester).border! as Border;
      expect(border.top.color, DonyColors.primary);
      expect(border.top.width, 2);
    });

    testWidgets('anneau transparent quand inactif', (tester) async {
      await tester.pumpWidget(
        host(buildItem(index: 4, currentIndex: 0, avatarName: 'Abou Diakite')),
      );

      final border = ringDecoration(tester).border! as Border;
      expect(border.top.color, Colors.transparent);
    });

    testWidgets('badge PRO masqué en mode avatar', (tester) async {
      await tester.pumpWidget(
        host(
          buildItem(
            index: 4,
            currentIndex: 4,
            isPro: true,
            avatarName: 'Abou Diakite',
          ),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });

  group('DonyNavItem — mode icône (avatarName null)', () {
    testWidgets('icône outlined quand inactif', (tester) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 0)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNothing);
      expect(find.byType(DonyAvatar), findsNothing);
    });

    testWidgets('icône filled quand actif', (tester) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 4)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    });

    testWidgets('étoile PRO affichée en mode icône', (tester) async {
      await tester.pumpWidget(
        host(buildItem(index: 4, currentIndex: 4, isPro: true)),
      );

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('pas d\'étoile PRO si isPro=false', (tester) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 4)));

      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });

  group('DonyNavItem — badge non lu', () {
    testWidgets('affiche le compteur quand badgeCount > 0', (tester) async {
      await tester.pumpWidget(
        host(buildItem(index: 3, currentIndex: 0, badgeCount: 3)),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('plafonne à 99+ au-delà de 99', (tester) async {
      await tester.pumpWidget(
        host(buildItem(index: 3, currentIndex: 0, badgeCount: 150)),
      );

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('aucun badge quand badgeCount = 0', (tester) async {
      await tester.pumpWidget(host(buildItem(index: 3, currentIndex: 0)));

      expect(find.text('0'), findsNothing);
    });
  });

  group('DonyNavItem — interaction', () {
    testWidgets('onTap déclenché au tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(buildItem(index: 4, currentIndex: 0, onTap: () => tapped = true)),
      );

      await tester.tap(find.byType(DonyNavItem));
      expect(tapped, isTrue);
    });
  });
}
