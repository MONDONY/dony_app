import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/assistant/bloc/assistant_voice_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/ai_form_draft_test_doubles.dart';

void main() {
  late FakeSpeechService speech;

  setUp(() => speech = FakeSpeechService());

  blocTest<AssistantVoiceCubit, AssistantVoiceState>(
    'dictée : texte partiel, puis final : la question est prête à partir',
    build: () => AssistantVoiceCubit(speech),
    act: (c) async {
      await c.start(localeId: 'fr_FR');
      speech
        ..emit('Comment')
        ..emit('Comment payer ?', isFinal: true);
    },
    expect: () => const [
      AssistantVoiceState(status: AssistantVoiceStatus.starting),
      AssistantVoiceState(status: AssistantVoiceStatus.listening),
      AssistantVoiceState(
        status: AssistantVoiceStatus.listening,
        transcript: 'Comment',
      ),
      AssistantVoiceState(
        status: AssistantVoiceStatus.listening,
        transcript: 'Comment payer ?',
      ),
      AssistantVoiceState(completed: 1, completedText: 'Comment payer ?'),
    ],
    verify: (_) {
      expect(speech.startCount, 1);
      expect(speech.lastLocaleId, 'fr_FR');
    },
  );

  blocTest<AssistantVoiceCubit, AssistantVoiceState>(
    'toggle pendant l’écoute : arrêt et envoi du texte reconnu',
    build: () => AssistantVoiceCubit(speech),
    act: (c) async {
      await c.toggle(localeId: 'en_US');
      speech.emit('Where is my parcel');
      await c.toggle(localeId: 'en_US');
    },
    skip: 3,
    expect: () => const [
      AssistantVoiceState(completed: 1, completedText: 'Where is my parcel'),
    ],
    verify: (c) {
      expect(speech.stopCount, 1);
      expect(c.state.listening, isFalse);
    },
  );

  blocTest<AssistantVoiceCubit, AssistantVoiceState>(
    'silence sans texte : retour au repos, rien à envoyer',
    build: () => AssistantVoiceCubit(speech),
    act: (c) async {
      await c.start(localeId: 'fr_FR');
      speech.finish();
    },
    skip: 2,
    expect: () => const [AssistantVoiceState()],
  );

  blocTest<AssistantVoiceCubit, AssistantVoiceState>(
    'micro refusé : indisponible, aucune écoute',
    build: () => AssistantVoiceCubit(speech..available = false),
    act: (c) => c.start(localeId: 'fr_FR'),
    expect: () => const [
      AssistantVoiceState(status: AssistantVoiceStatus.starting),
      AssistantVoiceState(status: AssistantVoiceStatus.unavailable),
    ],
    verify: (_) => expect(speech.startCount, 0),
  );

  blocTest<AssistantVoiceCubit, AssistantVoiceState>(
    'le plugin lève au démarrage : indisponible',
    build: () => AssistantVoiceCubit(_ThrowingSpeech()),
    act: (c) => c.start(localeId: 'fr_FR'),
    skip: 2,
    expect: () => const [
      AssistantVoiceState(status: AssistantVoiceStatus.unavailable),
    ],
  );

  blocTest<AssistantVoiceCubit, AssistantVoiceState>(
    'déjà en écoute : un second démarrage est ignoré ; stop au repos aussi',
    build: () => AssistantVoiceCubit(speech),
    act: (c) async {
      await c.stop();
      await c.start(localeId: 'fr_FR');
      await c.start(localeId: 'fr_FR');
    },
    verify: (_) {
      expect(speech.startCount, 1);
      expect(speech.stopCount, 0);
    },
  );

  test('fermeture : la dictée est annulée, plus rien n’est émis', () async {
    final cubit = AssistantVoiceCubit(speech);
    await cubit.start(localeId: 'fr_FR');
    await cubit.close();
    expect(speech.cancelCount, 1);
    speech.emit('trop tard', isFinal: true);
    expect(cubit.state.completed, 0);
  });

  blocTest<AssistantVoiceCubit, AssistantVoiceState>(
    'cancel pendant l’écoute : retour au repos, aucun completed, même si le '
    'résultat final arrive ensuite (YADONY-FLUTTER-PROD-X)',
    build: () => AssistantVoiceCubit(speech),
    act: (c) async {
      await c.start(localeId: 'fr_FR');
      speech.emit('Comment payer');
      await c.cancel();
      speech
        ..emit('Comment payer ?', isFinal: true)
        ..finish();
    },
    skip: 3,
    expect: () => const [AssistantVoiceState()],
    verify: (c) {
      // Une annulation par cancel, une par la fermeture du cubit.
      expect(speech.cancelCount, 2);
      expect(speech.stopCount, 0);
      expect(c.state.completed, 0);
    },
  );

  test('cancel pendant le démarrage : l’écoute ne commence jamais', () async {
    final cubit = AssistantVoiceCubit(speech);
    final starting = cubit.start(localeId: 'fr_FR');
    expect(cubit.state.status, AssistantVoiceStatus.starting);
    await cubit.cancel();
    await starting;
    expect(cubit.state.status, AssistantVoiceStatus.idle);
    expect(speech.startCount, 0);
    await cubit.close();
  });

  blocTest<AssistantVoiceCubit, AssistantVoiceState>(
    'cancel au repos : rien ne se passe',
    build: () => AssistantVoiceCubit(speech),
    act: (c) => c.cancel(),
    expect: () => const <AssistantVoiceState>[],
    // Seule la fermeture du cubit annule le moteur.
    verify: (_) => expect(speech.cancelCount, 1),
  );

  test('busy pendant le démarrage et l’écoute', () {
    expect(
      const AssistantVoiceState(status: AssistantVoiceStatus.starting).busy,
      isTrue,
    );
    expect(const AssistantVoiceState().busy, isFalse);
  });
}

class _ThrowingSpeech extends FakeSpeechService {
  @override
  Future<void> start({
    required String localeId,
    required void Function(String text, {required bool isFinal}) onResult,
    required void Function() onDone,
  }) async => throw StateError('plugin');
}
