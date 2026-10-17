import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
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

  testWidgets('clavier : le texte part et le champ se vide', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('ai-switch-keyboard')));
    await tester.pump();
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
    await tester.tap(find.byKey(const Key('ai-switch-voice')));
    await tester.pump();
    expect(find.byKey(const Key('ai-mic-start')), findsOneWidget);
  });

  testWidgets('micro indisponible : message et saisie écrite seule', (
    tester,
  ) async {
    await pump(tester, micUnavailable: true);
    expect(find.byKey(const Key('ai-mic-unavailable')), findsOneWidget);
    expect(find.text(fr.aiFormDraftMicUnavailable), findsOneWidget);
    expect(find.byKey(const Key('ai-text-input')), findsOneWidget);
    expect(find.byKey(const Key('ai-switch-voice')), findsNothing);
  });

  testWidgets('envoi en cours : boutons inactifs', (tester) async {
    await pump(tester, enabled: false);
    final mic = tester.widget<DonyButton>(
      find.byKey(const Key('ai-mic-start')),
    );
    expect(mic.onPressed, isNull);
  });

  testWidgets('démontage : la dictée est arrêtée', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(speech.cancelCount, 1);
  });
}
