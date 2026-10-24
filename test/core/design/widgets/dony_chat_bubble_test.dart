import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A6B3C),
            brightness: brightness,
          ),
        ),
        home: Scaffold(body: Center(child: child)),
      );

  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.byKey(const Key('chat-bubble-shell')),
    );
    return container.decoration! as BoxDecoration;
  }

  ColorScheme schemeOf(WidgetTester tester) => Theme.of(
    tester.element(find.byKey(const Key('chat-bubble-shell'))),
  ).colorScheme;

  testWidgets('ma bulle : couleur primaire, sans bordure ni ombre', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const DonyChatBubbleShell(isMe: true, child: Text('salut'))),
    );
    final d = decorationOf(tester);
    expect(d.color, schemeOf(tester).primary);
    expect(d.border, isNull);
    expect(d.boxShadow, isNull);
  });

  testWidgets('bulle de l\'autre : surface avec contour fin, sans ombre', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const DonyChatBubbleShell(isMe: false, child: Text('salut'))),
    );
    final d = decorationOf(tester);
    final cs = schemeOf(tester);
    expect(d.color, cs.surface);
    expect(d.border, Border.all(color: cs.outlineVariant));
    expect(d.boxShadow, isNull);
  });

  testWidgets('queue en bas à droite pour moi, à gauche pour l\'autre', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const DonyChatBubbleShell(isMe: true, child: Text('a'))),
    );
    var r = decorationOf(tester).borderRadius! as BorderRadius;
    expect(r.bottomRight, const Radius.circular(DonyRadius.xs));
    expect(r.bottomLeft, const Radius.circular(DonyRadius.card));

    await tester.pumpWidget(
      wrap(const DonyChatBubbleShell(isMe: false, child: Text('a'))),
    );
    r = decorationOf(tester).borderRadius! as BorderRadius;
    expect(r.bottomLeft, const Radius.circular(DonyRadius.xs));
    expect(r.bottomRight, const Radius.circular(DonyRadius.card));
  });

  testWidgets('tail false : rayon plein partout', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DonyChatBubbleShell(isMe: true, tail: false, child: Text('a')),
      ),
    );
    final r = decorationOf(tester).borderRadius! as BorderRadius;
    expect(r, BorderRadius.circular(DonyRadius.card));
  });

  testWidgets('meta affichée sous le contenu, dans la bulle', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DonyChatBubbleShell(
          isMe: true,
          meta: Text('14:05'),
          child: Text('salut'),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('chat-bubble-shell')),
        matching: find.text('14:05'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('14:05')).dy,
      greaterThan(tester.getTopLeft(find.text('salut')).dy),
    );
  });

  testWidgets('sans meta : rien sous le contenu', (tester) async {
    await tester.pumpWidget(
      wrap(const DonyChatBubbleShell(isMe: false, child: Text('salut'))),
    );
    expect(find.byKey(const Key('chat-bubble-meta')), findsNothing);
  });

  testWidgets('thème sombre : texte de l\'autre lisible (contraste ≥ 4,5)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const DonyChatBubbleShell(isMe: false, child: Text('salut')),
        brightness: Brightness.dark,
      ),
    );
    final cs = schemeOf(tester);
    final bg = decorationOf(tester).color!;
    double lum(Color c) => c.computeLuminance();
    final hi = lum(cs.onSurface) > lum(bg) ? cs.onSurface : bg;
    final lo = identical(hi, bg) ? cs.onSurface : bg;
    final ratio = (lum(hi) + 0.05) / (lum(lo) + 0.05);
    expect(ratio, greaterThanOrEqualTo(4.5));
  });

  testWidgets('thème sombre : ma bulle, onPrimary lisible sur primary', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const DonyChatBubbleShell(isMe: true, child: Text('salut')),
        brightness: Brightness.dark,
      ),
    );
    final cs = schemeOf(tester);
    final a = cs.primary.computeLuminance();
    final b = cs.onPrimary.computeLuminance();
    final ratio = (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
    expect(ratio, greaterThanOrEqualTo(4.5));
  });
}
