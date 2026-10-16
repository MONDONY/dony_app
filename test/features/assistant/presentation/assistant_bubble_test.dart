import 'dart:ui' show SemanticsAction;

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_bubble.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bubbleKey = ValueKey('assistant-bubble');
const _screen = Size(390, 844);

Finder get _bubble => find.byKey(_bubbleKey);

Rect _rect(WidgetTester tester) => tester.getRect(_bubble);

Future<void> _pumpBubble(
  WidgetTester tester, {
  String side = 'right',
  double y = 0.5,
  double bottomInset = 84,
  bool showHint = false,
  Size size = _screen,
  FakeViewPadding padding = FakeViewPadding.zero,
  ThemeData? theme,
  Locale locale = const Locale('fr'),
  bool disableAnimations = false,
  void Function(String, double)? onMoved,
  VoidCallback? onTap,
  VoidCallback? onHintDismissed,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Stack(
        children: [
          AssistantBubble(
            side: side,
            yFraction: y,
            bottomInset: bottomInset,
            showHint: showHint,
            onTap: onTap ?? () {},
            onMoved: onMoved ?? (_, _) {},
            onHintDismissed: onHintDismissed ?? () {},
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('AssistantBubbleZone', () {
    const zone = AssistantBubbleZone(
      left: 12,
      right: 322,
      top: 55,
      bottom: 636,
    );

    test('construite depuis la zone utile (safe area, barre d’onglets)', () {
      final z = AssistantBubbleZone.from(
        area: const Size(390, 844),
        padding: const EdgeInsets.only(top: 47, bottom: 34),
        bottomInset: 66,
      );
      expect(z.left, kAssistantBubbleMargin);
      expect(z.right, 390 - kAssistantBubbleMargin - kAssistantBubbleSize);
      expect(z.top, 47 + 8);
      expect(z.bottom, 844 - 66 - 34 - 8 - kAssistantBubbleSize);
    });

    test('zone trop basse : le haut l’emporte, jamais de zone inversée', () {
      final z = AssistantBubbleZone.from(
        area: const Size(300, 100),
        padding: EdgeInsets.zero,
        bottomInset: 66,
      );
      expect(z.bottom, z.top);
    });

    test('rest : côté et hauteur', () {
      expect(zone.rest('left', 0), const Offset(12, 55));
      expect(zone.rest('right', 1), const Offset(322, 636));
      expect(zone.rest('right', 0.5).dy, closeTo((55 + 636) / 2, 0.001));
      expect(zone.rest('inconnu', 0).dx, 322);
    });

    test('rest : une fraction hors 0..1 ou NaN reste dans la zone', () {
      expect(zone.rest('left', 3).dy, 636);
      expect(zone.rest('left', -2).dy, 55);
      expect(zone.rest('left', double.nan).dy, inInclusiveRange(55, 636));
    });

    test('fractionFor : inverse de rest, bornée', () {
      expect(zone.fractionFor(55), 0);
      expect(zone.fractionFor(636), 1);
      expect(zone.fractionFor(-400), 0);
      expect(zone.fractionFor(5000), 1);
      expect(zone.fractionFor(zone.rest('left', 0.3).dy), closeTo(0.3, 1e-9));
    });

    test('fractionFor sur une zone sans hauteur', () {
      const flat = AssistantBubbleZone(
        left: 12,
        right: 322,
        top: 55,
        bottom: 55,
      );
      expect(flat.fractionFor(200), inInclusiveRange(0, 1));
    });

    test('sideFor : moitié gauche ou droite de l’écran', () {
      expect(zone.sideFor(const Offset(100, 0), 390), 'left');
      expect(zone.sideFor(const Offset(300, 0), 390), 'right');
    });
  });

  group('placement', () {
    testWidgets('collée à droite au départ', (tester) async {
      await _pumpBubble(tester);
      expect(_rect(tester).right, closeTo(390 - kAssistantBubbleMargin, 0.5));
      expect(_rect(tester).size, const Size(56, 56));
    });

    testWidgets('collée à gauche quand on le demande', (tester) async {
      await _pumpBubble(tester, side: 'left');
      expect(_rect(tester).left, closeTo(kAssistantBubbleMargin, 0.5));
    });

    testWidgets('la fraction Y place la bulle dans la zone', (tester) async {
      await _pumpBubble(tester, y: 0);
      expect(_rect(tester).top, closeTo(8, 0.5));
      await _pumpBubble(tester, y: 1);
      expect(_rect(tester).bottom, closeTo(844 - 84 - 8, 0.5));
    });

    testWidgets('safe area du haut et du bas respectées', (tester) async {
      const padding = FakeViewPadding(top: 47, bottom: 34);
      await _pumpBubble(tester, y: 0, padding: padding);
      expect(_rect(tester).top, closeTo(47 + 8, 0.5));
      await _pumpBubble(tester, y: 1, padding: padding);
      expect(_rect(tester).bottom, closeTo(844 - 84 - 34 - 8, 0.5));
    });

    testWidgets('rotation : la position gardée est ramenée dans la zone', (
      tester,
    ) async {
      await _pumpBubble(tester, y: 1);
      expect(_rect(tester).bottom, closeTo(844 - 84 - 8, 0.5));
      await _pumpBubble(tester, y: 1, size: const Size(844, 390));
      final r = _rect(tester);
      expect(r.bottom, lessThanOrEqualTo(390 - 84));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.right, closeTo(844 - kAssistantBubbleMargin, 0.5));
    });

    testWidgets('écran minuscule : jamais hors de l’écran', (tester) async {
      await _pumpBubble(tester, y: 1, size: const Size(320, 120));
      final r = _rect(tester);
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(320));
    });

    testWidgets('changer de côté par les propriétés déplace la bulle', (
      tester,
    ) async {
      await _pumpBubble(tester);
      await _pumpBubble(tester, side: 'left');
      await tester.pumpAndSettle();
      expect(_rect(tester).left, closeTo(kAssistantBubbleMargin, 0.5));
    });
  });

  group('gestes', () {
    testWidgets('toucher ouvre', (tester) async {
      var taps = 0;
      await _pumpBubble(tester, onTap: () => taps++);
      await tester.tap(_bubble);
      expect(taps, 1);
    });

    testWidgets('lâchée à gauche du milieu : se colle à gauche, enregistre '
        'une seule fois et n’ouvre pas', (tester) async {
      var taps = 0;
      final moves = <(String, double)>[];
      await _pumpBubble(
        tester,
        onTap: () => taps++,
        onMoved: (s, f) => moves.add((s, f)),
      );
      final gesture = await tester.startGesture(tester.getCenter(_bubble));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-30, -10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(moves, isEmpty, reason: 'rien n’est écrit pendant le glissement');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(moves, hasLength(1));
      expect(moves.single.$1, 'left');
      expect(moves.single.$2, inInclusiveRange(0.0, 1.0));
      expect(taps, 0, reason: 'un glisser n’ouvre jamais l’assistant');
      expect(_rect(tester).left, closeTo(kAssistantBubbleMargin, 0.5));
    });

    testWidgets('lâchée du côté d’origine : reste à droite', (tester) async {
      String? side;
      await _pumpBubble(tester, onMoved: (s, _) => side = s);
      await tester.drag(_bubble, const Offset(-40, 80));
      await tester.pumpAndSettle();
      expect(side, 'right');
      expect(_rect(tester).right, closeTo(390 - kAssistantBubbleMargin, 0.5));
    });

    testWidgets('la fraction enregistrée suit la hauteur de lâcher', (
      tester,
    ) async {
      double? y;
      await _pumpBubble(tester, onMoved: (_, f) => y = f);
      await tester.drag(_bubble, const Offset(0, 150));
      await tester.pumpAndSettle();
      const zoneTop = 8.0;
      const zoneBottom = 844 - 84 - 8 - 56.0;
      expect(
        y,
        closeTo((_rect(tester).top - zoneTop) / (zoneBottom - zoneTop), 0.01),
      );
      expect(y, greaterThan(0.5));
    });

    testWidgets('lâchée sous la barre d’onglets : remonte dans la zone', (
      tester,
    ) async {
      double? y;
      await _pumpBubble(tester, y: 0.9, onMoved: (_, f) => y = f);
      await tester.drag(_bubble, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(_rect(tester).bottom, lessThanOrEqualTo(844 - 84));
      expect(y, 1.0);
    });

    testWidgets('lâchée au-dessus de la zone : redescend sous la safe area', (
      tester,
    ) async {
      double? y;
      await _pumpBubble(
        tester,
        padding: const FakeViewPadding(top: 47),
        onMoved: (_, f) => y = f,
      );
      await tester.drag(_bubble, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(_rect(tester).top, greaterThanOrEqualTo(47));
      expect(y, 0.0);
    });

    testWidgets('pendant le glissement la bulle suit le doigt, bornée', (
      tester,
    ) async {
      await _pumpBubble(tester);
      final start = _rect(tester).center;
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      expect(_rect(tester).center.dx, closeTo(start.dx - 200, 25));
      await gesture.moveBy(const Offset(-900, 0));
      await tester.pump();
      expect(_rect(tester).left, greaterThanOrEqualTo(0));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('reprendre la bulle pendant l’aimantation l’interrompt', (
      tester,
    ) async {
      await _pumpBubble(tester);
      await tester.drag(_bubble, const Offset(-250, 0));
      await tester.pump(const Duration(milliseconds: 40));
      final mid = _rect(tester);
      final gesture = await tester.startGesture(mid.center);
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      final held = _rect(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _rect(tester).center.dx,
        closeTo(held.center.dx, 1),
        reason: 'le ressort ne tire plus la bulle tenue au doigt',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('mouvement réduit : la bulle se pose sans animation', (
      tester,
    ) async {
      await _pumpBubble(tester, disableAnimations: true);
      await tester.drag(_bubble, const Offset(-300, 0));
      await tester.pump();
      expect(_rect(tester).left, closeTo(kAssistantBubbleMargin, 0.5));
    });

    testWidgets('l’aimantation dure moins de 300 ms', (tester) async {
      await _pumpBubble(tester);
      await tester.drag(_bubble, const Offset(-300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_rect(tester).left, closeTo(kAssistantBubbleMargin, 1));
    });

    testWidgets('l’aimantation ne sort jamais la bulle de l’écran', (
      tester,
    ) async {
      await _pumpBubble(tester);
      await tester.drag(_bubble, const Offset(-300, 0));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 12));
        final r = _rect(tester);
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(390));
      }
    });
  });

  group('bulle d’aide', () {
    testWidgets('affichée seulement si demandée', (tester) async {
      await _pumpBubble(tester, showHint: true);
      expect(find.textContaining('Une question sur l'), findsOneWidget);
      expect(find.textContaining('Glissez-moi'), findsOneWidget);
      await _pumpBubble(tester);
      expect(find.textContaining('Une question sur l'), findsNothing);
    });

    testWidgets('en anglais', (tester) async {
      await _pumpBubble(tester, showHint: true, locale: const Locale('en'));
      expect(find.text('A question about the app?'), findsOneWidget);
      expect(find.textContaining('Drag me anywhere'), findsOneWidget);
    });

    testWidgets('toucher l’aide la ferme sans ouvrir l’assistant', (
      tester,
    ) async {
      var dismissed = 0;
      var taps = 0;
      await _pumpBubble(
        tester,
        showHint: true,
        onTap: () => taps++,
        onHintDismissed: () => dismissed++,
      );
      await tester.tap(find.textContaining('Une question sur l'));
      expect(dismissed, 1);
      expect(taps, 0);
    });

    testWidgets('commencer à déplacer la bulle ferme l’aide', (tester) async {
      var dismissed = 0;
      await _pumpBubble(
        tester,
        showHint: true,
        onHintDismissed: () => dismissed++,
      );
      await tester.drag(_bubble, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    });

    testWidgets('l’aide reste dans l’écran, bulle à gauche ou à droite', (
      tester,
    ) async {
      for (final side in ['left', 'right']) {
        for (final y in [0.0, 1.0]) {
          await _pumpBubble(tester, showHint: true, side: side, y: y);
          final card = tester.getRect(
            find.ancestor(
              of: find.textContaining('Une question sur l'),
              matching: find.byKey(const ValueKey('assistant-hint')),
            ),
          );
          expect(card.left, greaterThanOrEqualTo(0), reason: '$side $y');
          expect(card.right, lessThanOrEqualTo(390), reason: '$side $y');
          expect(card.top, greaterThanOrEqualTo(0), reason: '$side $y');
          expect(card.bottom, lessThanOrEqualTo(844), reason: '$side $y');
          expect(
            card.overlaps(_rect(tester)),
            isFalse,
            reason: 'l’aide ne couvre pas la bulle ($side $y)',
          );
        }
      }
    });
  });

  group('accessibilité et rendu', () {
    testWidgets('bouton étiqueté, cible d’au moins 44 px', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpBubble(tester);
      final node = tester.getSemantics(_bubble);
      expect(node.label, "Ouvrir l'assistant");
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(_rect(tester).width, greaterThanOrEqualTo(44));
      expect(_rect(tester).height, greaterThanOrEqualTo(44));
      handle.dispose();
    });

    testWidgets('libellé en anglais', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpBubble(tester, locale: const Locale('en'));
      expect(find.bySemanticsLabel('Open the assistant'), findsOneWidget);
      handle.dispose();
    });

    for (final dark in [false, true]) {
      testWidgets(
        'couleurs unies des tokens du thème (${dark ? 'sombre' : 'clair'})',
        (tester) async {
          final theme = dark ? AppTheme.dark() : AppTheme.light();
          await _pumpBubble(tester, theme: theme, showHint: true);
          final material = tester.widget<Material>(
            find.descendant(of: _bubble, matching: find.byType(Material)).first,
          );
          expect(material.color, theme.colorScheme.primary);
          expect(material.shape, isA<CircleBorder>());
          expect(material.elevation, greaterThan(0));
          final icon = tester.widget<Icon>(
            find.descendant(of: _bubble, matching: find.byType(Icon)),
          );
          expect(icon.color, theme.colorScheme.onPrimary);
          // Aucun dégradé ni ombre colorée dure dans l’arbre de la bulle et de l’aide.
          for (final box in tester.widgetList<DecoratedBox>(
            find.byType(DecoratedBox),
          )) {
            final deco = box.decoration;
            if (deco is BoxDecoration) {
              expect(deco.gradient, isNull);
            }
          }
          final hint = tester.widget<Material>(
            find.byKey(const ValueKey('assistant-hint')),
          );
          expect(hint.color, theme.colorScheme.inverseSurface);
        },
      );
    }

    testWidgets('aucun tiret cadratin dans les textes de l’aide', (
      tester,
    ) async {
      for (final locale in [const Locale('fr'), const Locale('en')]) {
        await _pumpBubble(tester, showHint: true, locale: locale);
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          expect(t.data ?? '', isNot(contains('—')));
          expect(t.data ?? '', isNot(contains('–')));
        }
      }
    });
  });
}
