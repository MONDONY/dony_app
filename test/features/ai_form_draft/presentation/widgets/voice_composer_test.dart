import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_bloc.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/voice_composer.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/ai_form_draft_test_doubles.dart';
import '../../../../helpers/l10n_test_helpers.dart';

class _MockBloc extends MockBloc<AiFormDraftEvent, AiFormDraftState>
    implements AiFormDraftBloc {}

void main() {
  late _MockBloc bloc;
  late FakeSpeechService speech;
  final fr = lookupAppLocalizations(AppL10n.fr);

  setUpAll(() => registerFallbackValue(const AiFormDraftOpened()));

  setUp(() {
    bloc = _MockBloc();
    speech = FakeSpeechService();
    when(() => bloc.isClosed).thenReturn(false);
    whenListen(
      bloc,
      const Stream<AiFormDraftState>.empty(),
      initialState: const AiFormDraftState(kind: AiFormKind.trip),
    );
    getIt.registerSingleton<SpeechService>(speech);
  });

  tearDown(() => getIt.unregister<SpeechService>());

  Future<void> pump(
    WidgetTester tester, {
    bool enabled = true,
    bool listening = false,
    bool micUnavailable = false,
    Locale locale = AppL10n.fr,
  }) => tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: BlocProvider<AiFormDraftBloc>.value(
          value: bloc,
          child: AiVoiceComposer(
            enabled: enabled,
            listening: listening,
            micUnavailable: micUnavailable,
          ),
        ),
      ),
      locale: locale,
    ),
  );

  List<AiFormDraftEvent> added() =>
      verify(() => bloc.add(captureAny())).captured.cast<AiFormDraftEvent>();

  testWidgets('micro : écoute en français, texte partiel puis final', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('ai-mic-start')));
    await tester.pump();
    expect(speech.startCount, 1);
    expect(speech.lastLocaleId, 'fr_FR');
    speech.emit('Je voyage');
    speech.emit('Je voyage de Paris', isFinal: true);
    expect(added(), const [
      AiFormDraftMicPressed(),
      AiFormDraftSpeechPartial('Je voyage'),
      AiFormDraftSpeechPartial('Je voyage de Paris'),
      AiFormDraftMicStopped(),
    ]);
  });

  testWidgets('langue anglaise : écoute en en_US', (tester) async {
    enableEnglish();
    await pump(tester, locale: AppL10n.en);
    await tester.tap(find.byKey(const Key('ai-mic-start')));
    await tester.pump();
    expect(speech.lastLocaleId, 'en_US');
  });

  testWidgets('silence (fin d’écoute du plugin) : arrêt envoyé', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('ai-mic-start')));
    await tester.pump();
    speech.finish();
    expect(added().last, const AiFormDraftMicStopped());
  });

  testWidgets('micro refusé : MicUnavailable, aucune écoute', (tester) async {
    speech.available = false;
    await pump(tester);
    await tester.tap(find.byKey(const Key('ai-mic-start')));
    await tester.pump();
    expect(speech.startCount, 0);
    expect(added(), const [AiFormDraftMicUnavailable()]);
  });

  testWidgets('pendant l’écoute : « J’écoute… » arrête et envoie', (
    tester,
  ) async {
    await pump(tester, listening: true);
    expect(find.text(fr.aiFormDraftListening), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-mic-stop')));
    await tester.pump();
    expect(speech.stopCount, 1);
    expect(added(), const [AiFormDraftMicStopped()]);
  });

  testWidgets('champ écrit : le texte part et le champ se vide', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const Key('ai-text-input')),
      ' 23 kilos ',
    );
    await tester.tap(find.byKey(const Key('ai-send')));
    await tester.pump();
    expect(added(), const [AiFormDraftTextSubmitted('23 kilos')]);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai-text-input')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.tap(find.byKey(const Key('ai-send')));
    verifyNever(() => bloc.add(const AiFormDraftTextSubmitted('')));
  });

  testWidgets('gros micro rond (≥ 64 pt) centré au-dessus du champ', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);
    await pump(tester);
    final disc = tester.getRect(find.byKey(const Key('ai-mic-disc')));
    final input = tester.getRect(find.byKey(const Key('ai-text-input')));
    expect(disc.width, greaterThanOrEqualTo(64));
    expect(disc.height, greaterThanOrEqualTo(64));
    expect(disc.center.dx, closeTo(390 / 2, 1));
    expect(disc.bottom, lessThanOrEqualTo(input.top));
    expect(find.text('Touchez pour parler'), findsOneWidget);
  });

  testWidgets('micro indisponible : message et saisie écrite seule', (
    tester,
  ) async {
    await pump(tester, micUnavailable: true);
    expect(find.byKey(const Key('ai-mic-unavailable')), findsOneWidget);
    expect(find.text(fr.aiFormDraftMicUnavailable), findsOneWidget);
    expect(find.byKey(const Key('ai-text-input')), findsOneWidget);
    expect(find.byKey(const Key('ai-mic-start')), findsNothing);
  });

  testWidgets('envoi en cours : micro grisé, rien ne démarre', (tester) async {
    await pump(tester, enabled: false);
    await tester.tap(find.byKey(const Key('ai-mic-start')));
    await tester.pump();
    expect(speech.startCount, 0);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('ai-send'))).onPressed,
      isNull,
    );
  });

  testWidgets('pendant l’écoute : disque rouge et icône stop', (tester) async {
    await pump(tester, listening: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    final disc = tester.widget<AnimatedContainer>(
      find.byKey(const Key('ai-mic-disc')),
    );
    final decoration = disc.decoration! as BoxDecoration;
    expect(
      decoration.color,
      Theme.of(
        tester.element(find.byKey(const Key('ai-mic-disc'))),
      ).colorScheme.error,
    );
  });

  testWidgets('clavier ouvert : le micro s’efface, le champ reste', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('ai-mic-start')), findsNothing);
    expect(find.byKey(const Key('ai-text-input')), findsOneWidget);
  });

  testWidgets('clavier ouvert pendant l’écoute : le stop reste accessible', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);
    await pump(tester, listening: true);
    expect(find.byKey(const Key('ai-mic-stop')), findsOneWidget);
  });

  testWidgets('animations réduites : micro affiché, écoute possible', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester, listening: true);
    await tester.pump();
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-mic-stop')));
    await tester.pump();
    expect(speech.stopCount, 1);
  });

  testWidgets('démontage : la dictée est arrêtée', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(speech.cancelCount, 1);
  });
}
