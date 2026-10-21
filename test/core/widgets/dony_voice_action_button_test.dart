import 'package:dony/core/widgets/dony_voice_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var micTaps = 0;
  var sendTaps = 0;

  setUp(() {
    micTaps = 0;
    sendTaps = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    bool hasText = false,
    bool listening = false,
    bool micAvailable = true,
    bool enabled = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: DonyVoiceActionButton(
            hasText: hasText,
            listening: listening,
            micAvailable: micAvailable,
            enabled: enabled,
            onMic: () => micTaps++,
            onSend: () => sendTaps++,
            micTooltip: 'Parler',
            stopTooltip: 'Arrêter',
            sendTooltip: 'Envoyer',
            micKey: const Key('mic'),
            stopKey: const Key('stop'),
            sendKey: const Key('send'),
          ),
        ),
      ),
    ),
  );

  test('action : micro au repos, envoi dès qu’il y a du texte', () {
    DonyVoiceAction action({
      bool hasText = false,
      bool listening = false,
      bool micAvailable = true,
    }) => DonyVoiceActionButton(
      hasText: hasText,
      listening: listening,
      micAvailable: micAvailable,
      enabled: true,
      onMic: () {},
      onSend: () {},
      micTooltip: '',
      stopTooltip: '',
      sendTooltip: '',
    ).action;

    expect(action(), DonyVoiceAction.mic);
    expect(action(hasText: true), DonyVoiceAction.send);
    // L'arrêt prime sur tout pendant la dictée, texte reconnu compris.
    expect(action(listening: true), DonyVoiceAction.stop);
    expect(action(listening: true, hasText: true), DonyVoiceAction.stop);
    // Sans micro, il ne reste que l'envoi.
    expect(action(micAvailable: false), DonyVoiceAction.send);
  });

  testWidgets('micro : 48 pt, démarre la dictée', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('mic')), findsOneWidget);
    expect(find.byKey(const Key('send')), findsNothing);
    final size = tester.getSize(find.byKey(const Key('mic')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byKey(const Key('mic')));
    expect(micTaps, 1);
    expect(sendTaps, 0);
  });

  testWidgets('texte saisi : la flèche d’envoi remplace le micro', (
    tester,
  ) async {
    await pump(tester, hasText: true);
    expect(find.byKey(const Key('mic')), findsNothing);
    await tester.tap(find.byKey(const Key('send')));
    expect(sendTaps, 1);
    expect(micTaps, 0);
  });

  testWidgets('dictée : bouton rouge, un toucher arrête', (tester) async {
    await pump(tester, listening: true);
    final stop = tester.widget<IconButton>(find.byKey(const Key('stop')));
    expect(
      stop.style!.backgroundColor!.resolve(<WidgetState>{}),
      ThemeData().colorScheme.error,
    );
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('stop')));
    expect(micTaps, 1);
  });

  testWidgets('réponse en route : micro et envoi grisés, arrêt possible', (
    tester,
  ) async {
    await pump(tester, enabled: false);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('mic'))).onPressed,
      isNull,
    );
    await pump(tester, enabled: false, hasText: true);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('send'))).onPressed,
      isNull,
    );
    await pump(tester, enabled: false, listening: true);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('stop'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('sans micro : envoi grisé tant que le champ est vide', (
    tester,
  ) async {
    await pump(tester, micAvailable: false);
    expect(find.byKey(const Key('mic')), findsNothing);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('send'))).onPressed,
      isNull,
    );
    await pump(tester, micAvailable: false, hasText: true);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('send'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('infobulles : une par action', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Parler'), findsOneWidget);
    await pump(tester, hasText: true);
    expect(find.byTooltip('Envoyer'), findsOneWidget);
    await pump(tester, listening: true);
    expect(find.byTooltip('Arrêter'), findsOneWidget);
  });

  testWidgets('animations réduites : pas de transition', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester);
    await pump(tester, hasText: true);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
  });
}
