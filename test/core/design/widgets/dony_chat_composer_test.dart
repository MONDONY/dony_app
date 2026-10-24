import 'package:dony/core/design/widgets/dony_chat_composer.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plus = Key('chat-attach-button');
  const camera = Key('chat-camera-button');
  const send = Key('chat-send-button');

  Widget wrap(
    Widget child, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) => MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A6B3C),
        brightness: brightness,
      ),
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: AppL10n.fr,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: Align(alignment: Alignment.bottomCenter, child: child),
    ),
  );

  late TextEditingController controller;
  late int sent;
  late int plusTaps;
  late int cameraTaps;
  late int lockedTaps;

  setUp(() {
    controller = TextEditingController();
    sent = 0;
    plusTaps = 0;
    cameraTaps = 0;
    lockedTaps = 0;
  });
  tearDown(() => controller.dispose());

  DonyChatComposer composer({
    bool sending = false,
    bool locked = false,
    bool withAttach = true,
    Widget? above,
    bool Function(String)? canSend,
  }) => DonyChatComposer(
    controller: controller,
    hintText: 'Message',
    onSend: () => sent++,
    canSend: canSend ?? (d) => d.trim().isNotEmpty,
    sending: sending,
    above: above,
    attach: withAttach
        ? DonyComposerAttach(
            onPlus: () => plusTaps++,
            onCamera: () => cameraTaps++,
            onLocked: () => lockedTaps++,
            locked: locked,
          )
        : null,
  );

  testWidgets('champ vide : « + » et appareil photo visibles, envoi grisé', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(composer()));
    expect(find.byKey(plus), findsOneWidget);
    expect(find.byKey(camera), findsOneWidget);
    await tester.tap(find.byKey(send));
    await tester.pump();
    expect(sent, 0);
  });

  testWidgets('texte saisi : appareil photo masqué, envoi actif', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(composer()));
    controller.text = 'bonjour';
    await tester.pump();
    expect(find.byKey(camera), findsNothing);
    expect(find.byKey(plus), findsOneWidget);
    await tester.tap(find.byKey(send));
    await tester.pump();
    expect(sent, 1);
  });

  testWidgets('sending : spinner, aucun envoi même en tapant deux fois', (
    tester,
  ) async {
    controller.text = 'bonjour';
    await tester.pumpWidget(wrap(composer(sending: true)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(send), warnIfMissed: false);
    await tester.tap(find.byKey(send), warnIfMissed: false);
    await tester.pump();
    expect(sent, 0);
  });

  testWidgets('verrouillé : « + » et appareil photo appellent onLocked', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(composer(locked: true)));
    await tester.tap(find.byKey(plus));
    await tester.tap(find.byKey(camera));
    await tester.pump();
    expect(lockedTaps, 2);
    expect(plusTaps, 0);
    expect(cameraTaps, 0);
  });

  testWidgets('actif : « + » et appareil photo appellent leurs actions', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(composer()));
    await tester.tap(find.byKey(plus));
    await tester.tap(find.byKey(camera));
    await tester.pump();
    expect(plusTaps, 1);
    expect(cameraTaps, 1);
    expect(lockedTaps, 0);
  });

  testWidgets('sans attach : ni « + » ni appareil photo', (tester) async {
    await tester.pumpWidget(wrap(composer(withAttach: false)));
    expect(find.byKey(plus), findsNothing);
    expect(find.byKey(camera), findsNothing);
    expect(find.byKey(send), findsOneWidget);
  });

  testWidgets('above : rendu au-dessus de la pilule', (tester) async {
    await tester.pumpWidget(
      wrap(composer(above: const Text('vignettes', key: Key('strip')))),
    );
    expect(
      tester.getBottomLeft(find.byKey(const Key('strip'))).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const Key('chat-composer-pill'))).dy,
      ),
    );
  });

  testWidgets('canSend reçoit le texte : envoi actif sans texte si décidé', (
    tester,
  ) async {
    String? seen;
    await tester.pumpWidget(
      wrap(
        composer(
          canSend: (d) {
            seen = d;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(send));
    await tester.pump();
    expect(seen, '');
    expect(sent, 1);
  });

  testWidgets('texte très long : la pilule plafonne à 132 px', (tester) async {
    controller.text = List.filled(60, 'ligne de texte').join('\n');
    await tester.pumpWidget(wrap(composer()));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('chat-composer-pill'))).height,
      lessThanOrEqualTo(132),
    );
    expect(find.byKey(send), findsOneWidget);
  });

  testWidgets('texte agrandi à 200 % : pas de débordement, cibles ≥ 44', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(composer(), textScale: 2));
    expect(tester.takeException(), isNull);
    for (final key in [plus, camera, send]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(44), reason: '$key');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$key');
    }
  });

  testWidgets('action du clavier : onSubmitted reçoit le texte', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      wrap(
        DonyChatComposer(
          controller: controller,
          hintText: 'Message',
          onSend: () {},
          canSend: (_) => true,
          onSubmitted: (v) => submitted = v,
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('chat-composer-field')), 'ok');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, 'ok');
  });

  testWidgets('envoi : toute la zone de 44 pt est tactile, bords compris', (
    tester,
  ) async {
    controller.text = 'bonjour';
    await tester.pumpWidget(wrap(composer()));
    final box = tester.getRect(find.byKey(send));
    await tester.tapAt(box.topLeft + const Offset(2, 2));
    await tester.pump();
    expect(sent, 1);
  });

  testWidgets('thèmes clair et sombre : sans exception', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(wrap(composer(), brightness: b));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Semantics : libellés selon l\'état', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(composer()));
    expect(find.bySemanticsLabel('Envoyer une photo'), findsOneWidget);
    expect(find.bySemanticsLabel('Prendre une photo'), findsOneWidget);
    expect(find.bySemanticsLabel('Envoyer le message'), findsOneWidget);
    await tester.pumpWidget(wrap(composer(locked: true)));
    expect(
      find.bySemanticsLabel('Envoi de photos indisponible pour le moment'),
      findsNWidgets(2),
    );
    handle.dispose();
  });
}
