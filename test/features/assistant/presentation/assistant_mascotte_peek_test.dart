import 'package:dony/features/assistant/presentation/widgets/assistant_bubble.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_mascotte_peek.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = Size(390, 844);
const _peekKey = ValueKey('assistant-mascotte');
const _tipKey = ValueKey('assistant-mascotte-tip');
const _bubbleKey = ValueKey('assistant-bubble');

Finder get _mascotte => find.byKey(_peekKey);
Finder get _tip => find.byKey(_tipKey);

Future<void> _pump(
  WidgetTester tester, {
  String side = 'right',
  double y = 0.5,
  bool showMascotte = true,
  bool showHint = false,
  Locale locale = const Locale('fr'),
  bool disableAnimations = false,
  void Function(int)? onShown,
  VoidCallback? onCompleted,
  VoidCallback? onTap,
  VoidCallback? onMascotteTap,
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
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
            bottomInset: 84,
            showHint: showHint,
            onTap: onTap ?? () {},
            onMoved: (_, _) {},
            onHintDismissed: () {},
            showMascotte: showMascotte,
            onMascotteShown: onShown,
            onMascotteCompleted: onCompleted,
            onMascotteTap: onMascotteTap,
          ),
        ],
      ),
    ),
  );
}

/// Joue le temps [d] image par image (les tickers n'avancent qu'à `pump`).
Future<void> _play(WidgetTester tester, Duration d) async {
  const step = Duration(milliseconds: 100);
  var left = d;
  while (left > Duration.zero) {
    final next = left < step ? left : step;
    await tester.pump(next);
    left -= next;
  }
}

Rect _bubbleRect(WidgetTester tester) => tester.getRect(find.byKey(_bubbleKey));

void main() {
  group('courbes', () {
    test('la mascotte est cachée sous la bulle au début et à la fin', () {
      for (final ms in [0.0, 200.0, 6700.0]) {
        final p = assistantMascottePoseAt(ms);
        expect(p.scale, closeTo(0.3, 1e-9), reason: '$ms ms');
        expect(p.offset, closeTo(14, 1e-9), reason: '$ms ms');
        expect(p.tiltDegrees, 0, reason: '$ms ms');
      }
    });

    test('elle jaillit avec un petit dépassement puis se pose', () {
      final overshoot = assistantMascottePoseAt(720);
      expect(overshoot.scale, closeTo(1.06, 1e-9));
      expect(overshoot.offset, lessThan(0));
      final settled = assistantMascottePoseAt(900);
      expect(settled.scale, 1);
      expect(settled.offset, 0);
      expect(settled.tiltDegrees, 0);
    });

    test('le coucou balance de part et d’autre', () {
      expect(assistantMascottePoseAt(1170).tiltDegrees, lessThan(-8));
      expect(assistantMascottePoseAt(1530).tiltDegrees, greaterThan(8));
      expect(assistantMascottePoseAt(1890).tiltDegrees, lessThan(-8));
      expect(assistantMascottePoseAt(3500).tiltDegrees, 0);
    });

    test('elle replonge dans la bulle à la fin', () {
      final early = assistantMascottePoseAt(5900);
      final late = assistantMascottePoseAt(6300);
      expect(early.scale, lessThan(1.03));
      expect(late.scale, closeTo(0.3, 1e-9));
    });

    test('la phrase apparaît après le coucou et disparaît avant la fin', () {
      expect(assistantMascotteTipAt(0), 0);
      expect(assistantMascotteTipAt(1000), 0);
      expect(assistantMascotteTipAt(2000), 1);
      expect(assistantMascotteTipAt(5000), 1);
      expect(assistantMascotteTipAt(5600), 0);
      expect(assistantMascotteTipAt(6700), 0);
    });

    test('la bulle se tasse avant la sortie puis reprend sa forme', () {
      expect(assistantMascotteBubbleScaleAt(0), 1);
      expect(assistantMascotteBubbleScaleAt(315), closeTo(0.9, 1e-9));
      expect(assistantMascotteBubbleScaleAt(540), closeTo(1.07, 1e-9));
      expect(assistantMascotteBubbleScaleAt(3000), 1);
      expect(assistantMascotteBubbleScaleAt(6345), closeTo(0.93, 1e-9));
      expect(assistantMascotteBubbleScaleAt(6700), 1);
    });

    test('mouvement réduit : fondu seulement', () {
      expect(assistantMascotteCalmOpacityAt(0), 0);
      expect(assistantMascotteCalmOpacityAt(2000), 1);
      expect(assistantMascotteCalmOpacityAt(6700), 0);
    });

    test('hors bornes : valeurs des extrémités', () {
      expect(assistantMascottePoseAt(-50).scale, closeTo(0.3, 1e-9));
      expect(assistantMascottePoseAt(99999).scale, closeTo(0.3, 1e-9));
    });
  });

  group('passages', () {
    testWidgets('rien avant le premier délai', (tester) async {
      var shown = 0;
      await _pump(tester, onShown: (_) => shown++);
      await _play(tester, const Duration(seconds: 5));
      expect(_mascotte, findsNothing);
      expect(shown, 0);
    });

    testWidgets('elle sort, salue et affiche la phrase', (tester) async {
      final counts = <int>[];
      await _pump(tester, onShown: counts.add);
      await _play(tester, kAssistantMascotteFirstDelay);
      expect(counts, [1]);
      await _play(tester, const Duration(milliseconds: 2500));
      expect(_mascotte, findsOneWidget);
      expect(_tip, findsOneWidget);
      expect(find.text('Comment puis-je vous aider ?'), findsOneWidget);
    });

    testWidgets('phrase en anglais', (tester) async {
      await _pump(tester, locale: const Locale('en'));
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      expect(find.text('How can I help?'), findsOneWidget);
    });

    testWidgets('elle rentre puis revient après l’intervalle', (tester) async {
      final counts = <int>[];
      await _pump(tester, onShown: counts.add);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + kAssistantMascotteShow,
      );
      // Le premier tick du passage part à l'image suivant le minuteur : la
      // fin tombe un peu après la durée nominale.
      await _play(tester, const Duration(milliseconds: 300));
      expect(_mascotte, findsNothing);
      expect(counts, [1]);
      await _play(
        tester,
        kAssistantMascotteInterval - const Duration(seconds: 2),
      );
      expect(counts, [1]);
      await _play(tester, const Duration(seconds: 3));
      expect(counts, [1, 2]);
      await _play(tester, const Duration(milliseconds: 2500));
      expect(_mascotte, findsOneWidget);
    });

    testWidgets('la fin d’un passage est signalée une fois par passage', (
      tester,
    ) async {
      var completed = 0;
      await _pump(tester, onCompleted: () => completed++);
      await _play(tester, kAssistantMascotteFirstDelay);
      await _play(tester, const Duration(milliseconds: 2000));
      expect(completed, 0, reason: 'en plein passage');
      await _play(tester, kAssistantMascotteShow);
      expect(completed, 1);
      await _play(tester, kAssistantMascotteInterval);
      await _play(tester, kAssistantMascotteShow);
      expect(completed, 2);
    });

    testWidgets('un passage interrompu n’est pas compté', (tester) async {
      var completed = 0;
      await _pump(tester, onCompleted: () => completed++);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2000),
      );
      final gesture = await tester.startGesture(_bubbleRect(tester).center);
      await gesture.moveBy(const Offset(-30, -30));
      await tester.pump();
      await gesture.up();
      await _play(tester, const Duration(seconds: 10));
      expect(completed, 0);
    });

    testWidgets('showMascotte faux : jamais de passage', (tester) async {
      var shown = 0;
      await _pump(tester, showMascotte: false, onShown: (_) => shown++);
      await _play(tester, const Duration(seconds: 90));
      expect(shown, 0);
      expect(_mascotte, findsNothing);
    });

    testWidgets('le démontage annule le minuteur en attente', (tester) async {
      var shown = 0;
      await _pump(tester, onShown: (_) => shown++);
      await _play(tester, const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      await _play(tester, const Duration(seconds: 120));
      expect(shown, 0);
    });

    testWidgets('l’aide de première fois repousse le passage', (tester) async {
      final counts = <int>[];
      await _pump(tester, showHint: true, onShown: counts.add);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(seconds: 6),
      );
      expect(counts, isEmpty);
      expect(_mascotte, findsNothing);
      // L’aide se ferme (le parent remonte la bulle sans aide) : le passage
      // reporté repart au prochain essai, 5 s au plus.
      await _pump(tester, onShown: counts.add);
      await _play(tester, const Duration(seconds: 6));
      expect(counts, [1]);
    });

    testWidgets('un glissement en plein passage la fait rentrer', (
      tester,
    ) async {
      final counts = <int>[];
      await _pump(tester, onShown: counts.add);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2000),
      );
      expect(_mascotte, findsOneWidget);
      final gesture = await tester.startGesture(_bubbleRect(tester).center);
      await gesture.moveBy(const Offset(-30, -30));
      await tester.pump();
      expect(_mascotte, findsNothing);
      await gesture.up();
      await _play(tester, const Duration(seconds: 1));
      // Le passage suivant est celui de l’intervalle normal.
      expect(counts, [1]);
      await _play(
        tester,
        kAssistantMascotteInterval + const Duration(seconds: 1),
      );
      expect(counts, [1, 2]);
    });

    testWidgets('un passage tombant pendant un glissement est reporté', (
      tester,
    ) async {
      final counts = <int>[];
      await _pump(tester, onShown: counts.add);
      await _play(
        tester,
        kAssistantMascotteFirstDelay - const Duration(seconds: 1),
      );
      final gesture = await tester.startGesture(_bubbleRect(tester).center);
      await gesture.moveBy(const Offset(-20, -20));
      await tester.pump();
      await _play(tester, const Duration(seconds: 2));
      expect(counts, isEmpty);
      await gesture.up();
      await _play(tester, const Duration(seconds: 7));
      expect(counts, [1]);
    });
  });

  group('toucher', () {
    testWidgets('la mascotte ouvre l’assistant par onMascotteTap', (
      tester,
    ) async {
      var mascotte = 0;
      var bubble = 0;
      await _pump(
        tester,
        onTap: () => bubble++,
        onMascotteTap: () => mascotte++,
      );
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      await tester.tapAt(tester.getRect(_mascotte).center);
      expect(mascotte, 1);
      expect(bubble, 0);
    });

    testWidgets('la phrase ouvre aussi l’assistant', (tester) async {
      var mascotte = 0;
      await _pump(tester, onMascotteTap: () => mascotte++);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      await tester.tap(find.text('Comment puis-je vous aider ?'));
      expect(mascotte, 1);
    });

    testWidgets('sans onMascotteTap, elle appelle onTap', (tester) async {
      var bubble = 0;
      await _pump(tester, onTap: () => bubble++);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      await tester.tapAt(tester.getRect(_mascotte).center);
      expect(bubble, 1);
    });

    testWidgets('phrase lue comme un seul bouton', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Comment puis-je vous aider ?'),
        ),
        matchesSemantics(
          label: 'Comment puis-je vous aider ?',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('placement', () {
    testWidgets('au milieu : sort vers le haut, derrière la bulle', (
      tester,
    ) async {
      await _pump(tester);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      final m = tester.getRect(_mascotte);
      final b = _bubbleRect(tester);
      expect(
        m.size,
        const Size(kAssistantMascotteSize, kAssistantMascotteSize),
      );
      expect(m.bottom, closeTo(b.top + 8, 0.01));
      expect(m.center.dx, closeTo(b.center.dx, 0.01));
    });

    testWidgets('collée au haut de l’écran : sort vers le bas', (tester) async {
      await _pump(tester, y: 0);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      final m = tester.getRect(_mascotte);
      final b = _bubbleRect(tester);
      expect(m.top, closeTo(b.bottom - 8, 0.01));
    });

    testWidgets('bulle à droite : la phrase est à gauche de la mascotte', (
      tester,
    ) async {
      await _pump(tester);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      expect(
        tester.getRect(_tip).right,
        lessThanOrEqualTo(tester.getRect(_mascotte).left + 0.5),
      );
      expect(tester.getRect(_tip).left, greaterThanOrEqualTo(0));
    });

    testWidgets('bulle à gauche : la phrase est à droite de la mascotte', (
      tester,
    ) async {
      await _pump(tester, side: 'left');
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      expect(
        tester.getRect(_tip).left,
        greaterThanOrEqualTo(tester.getRect(_mascotte).right - 0.5),
      );
      expect(tester.getRect(_tip).right, lessThanOrEqualTo(_screen.width));
      final image = tester.widget<Transform>(
        find.descendant(of: _mascotte, matching: find.byType(Transform)).last,
      );
      // Retournée à gauche : sa main reste visible.
      expect(image.transform.storage[0], lessThan(0));
    });

    testWidgets('à droite : la mascotte n’est pas retournée', (tester) async {
      await _pump(tester);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      final image = tester.widget<Transform>(
        find.descendant(of: _mascotte, matching: find.byType(Transform)).last,
      );
      expect(image.transform.storage[0], greaterThan(0));
    });

    testWidgets('jamais hors de l’écran, texte à 150 %', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Stack(
            children: [
              AssistantBubble(
                side: 'right',
                yFraction: 0.5,
                bottomInset: 84,
                showHint: false,
                onTap: () {},
                onMoved: (_, _) {},
                onHintDismissed: () {},
                showMascotte: true,
              ),
            ],
          ),
        ),
      );
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 2500),
      );
      final tip = tester.getRect(_tip);
      final m = tester.getRect(_mascotte);
      expect(tip.left, greaterThanOrEqualTo(0));
      expect(m.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  });

  group('mouvement réduit', () {
    testWidgets('fondu seulement : la mascotte ne bouge pas', (tester) async {
      await _pump(tester, disableAnimations: true);
      await _play(tester, kAssistantMascotteFirstDelay);
      await _play(tester, const Duration(milliseconds: 1000));
      final during = tester.getRect(_mascotte);
      await _play(tester, const Duration(milliseconds: 1500));
      expect(tester.getRect(_mascotte), during);
      expect(find.text('Comment puis-je vous aider ?'), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.descendant(of: _mascotte, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('la bulle ne se tasse pas', (tester) async {
      await _pump(tester, disableAnimations: true);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 400),
      );
      final size = _bubbleRect(tester).size;
      expect(size, const Size(kAssistantBubbleSize, kAssistantBubbleSize));
    });
  });

  group('bulle', () {
    testWidgets('elle se tasse quand la mascotte sort', (tester) async {
      await _pump(tester);
      await _play(
        tester,
        kAssistantMascotteFirstDelay + const Duration(milliseconds: 315),
      );
      final scaled = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byKey(_bubbleKey),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.storage[0]);
      expect(scaled.any((s) => s < 0.95), isTrue);
      await _play(tester, const Duration(seconds: 3));
      final calm = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byKey(_bubbleKey),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.storage[0]);
      expect(calm.every((s) => s > 0.99), isTrue);
    });
  });
}
