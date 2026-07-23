import 'package:dony/app/widgets/dony_nav_item.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ColorScheme minimal calé sur les tokens dony — évite google_fonts (réseau)
  // tout en garantissant cs.primary == DonyColors.primary pour les assertions.
  const scheme = ColorScheme.light(
    primary: DonyColors.primary,
    onPrimary: Colors.white,
    surface: DonyColors.surface,
    onSurfaceVariant: DonyColors.textSubtle,
  );

  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(useMaterial3: true, colorScheme: scheme),
    home: Scaffold(
      body: Center(child: SizedBox(height: 80, width: 120, child: child)),
    ),
  );

  DonyNavItem buildItem({
    required int index,
    required int currentIndex,
    int badgeCount = 0,
    bool showDot = false,
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
    showDot: showDot,
    isPro: isPro,
    avatarUrl: avatarUrl,
    avatarName: avatarName,
  );

  // Le point d'attention : Container 10×10, rempli error, cercle, sans enfant.
  // Se distingue du badge chiffré (rectangle arrondi + Text) et de l'étoile PRO
  // (couleur warning).
  Finder attentionDot() => find.byWidgetPredicate((w) {
        if (w is! Container || w.child != null) {
          return false;
        }
        final deco = w.decoration;
        return deco is BoxDecoration &&
            deco.shape == BoxShape.circle &&
            deco.color == DonyColors.error;
      });

  // Décoration de l'anneau (AnimatedContainer ancêtre du DonyAvatar).
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
      // Le libellé est désormais toujours rendu visuellement sous l'icône.
      expect(find.text('Moi'), findsOneWidget);
    });

    testWidgets('anneau primary quand actif', (tester) async {
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

      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'star'),
        findsNothing,
      );
    });
  });

  group('DonyNavItem — mode icône (fill délégué à l’indicateur partagé)', () {
    testWidgets(
      'ne peint plus sa propre pastille (AnimatedContainer) — le fond '
      'actif est désormais l’indicateur glissant du parent (_DonyBottomNav)',
      (tester) async {
        await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 4)));
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedContainer), findsNothing);
      },
    );

    testWidgets('icône outlined + couleur subtle quand inactif', (
      tester,
    ) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 0)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNothing);
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.person_outline_rounded),
      );
      expect(icon.color, DonyColors.textSubtle);
    });

    testWidgets('icône filled + couleur blanche quand actif', (tester) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 4)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(Icons.person_rounded));
      expect(icon.color, Colors.white);
    });

    testWidgets('étoile PRO affichée en mode icône', (tester) async {
      await tester.pumpWidget(
        host(buildItem(index: 4, currentIndex: 4, isPro: true)),
      );

      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'star'),
        findsOneWidget,
      );
    });

    testWidgets('pas d\'étoile PRO si isPro=false', (tester) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 4)));

      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'star'),
        findsNothing,
      );
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

  group('DonyNavItem — point d\'attention (showDot)', () {
    testWidgets('affiche le point quand showDot = true', (tester) async {
      await tester.pumpWidget(
        host(buildItem(index: 1, currentIndex: 0, showDot: true)),
      );

      expect(attentionDot(), findsOneWidget);
    });

    testWidgets('pas de point quand showDot = false', (tester) async {
      await tester.pumpWidget(host(buildItem(index: 1, currentIndex: 0)));

      expect(attentionDot(), findsNothing);
    });

    testWidgets('le badge chiffré a priorité sur le point', (tester) async {
      await tester.pumpWidget(
        host(buildItem(index: 1, currentIndex: 0, showDot: true, badgeCount: 2)),
      );

      // Un décompte précis existe : on montre le nombre, pas le point nu.
      expect(find.text('2'), findsOneWidget);
      expect(attentionDot(), findsNothing);
    });
  });

  group('DonyNavItem — libellé visible (audit UX bottom nav)', () {
    testWidgets('libellé en primary quand actif', (tester) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 4)));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Moi'));
      expect(text.style?.color, DonyColors.primary);
      expect(text.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('libellé en onSurfaceVariant quand inactif', (tester) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 0)));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Moi'));
      expect(text.style?.color, DonyColors.textSubtle);
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('libellé exclu de l\'arbre sémantique (pas de double annonce)', (
      tester,
    ) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 4)));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text('Moi'),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });

  group('DonyNavItem — accessibilité & interaction', () {
    testWidgets('expose le libellé + état sélectionné via Semantics', (
      tester,
    ) async {
      await tester.pumpWidget(host(buildItem(index: 4, currentIndex: 4)));

      final node = tester.getSemantics(find.bySemanticsLabel('Moi'));
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
    });

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
