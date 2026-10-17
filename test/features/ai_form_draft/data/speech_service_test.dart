import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _MockSpeechToText extends Mock implements SpeechToText {}

void main() {
  late _MockSpeechToText stt;
  late SttSpeechService service;

  setUpAll(() => registerFallbackValue(SpeechListenOptions()));

  setUp(() {
    stt = _MockSpeechToText();
    service = SttSpeechService(stt);
    when(
      () => stt.listen(
        onResult: any(named: 'onResult'),
        listenOptions: any(named: 'listenOptions'),
      ),
    ).thenAnswer((_) async {});
    when(() => stt.stop()).thenAnswer((_) async {});
    when(() => stt.cancel()).thenAnswer((_) async {});
  });

  void initializes(bool result) => when(
    () => stt.initialize(
      onStatus: any(named: 'onStatus'),
      onError: any(named: 'onError'),
    ),
  ).thenAnswer((_) async => result);

  /// Rappels `onStatus` et `onError` passés au plugin.
  (void Function(String), void Function(SpeechRecognitionError)) callbacks() {
    final captured = verify(
      () => stt.initialize(
        onStatus: captureAny(named: 'onStatus'),
        onError: captureAny(named: 'onError'),
      ),
    ).captured;
    return (
      captured[0] as void Function(String),
      captured[1] as void Function(SpeechRecognitionError),
    );
  }

  test(
    'initialize réussi : mis en cache, le plugin n’est appelé qu’une fois',
    () async {
      initializes(true);
      expect(await service.initialize(), isTrue);
      expect(await service.initialize(), isTrue);
      verify(
        () => stt.initialize(
          onStatus: any(named: 'onStatus'),
          onError: any(named: 'onError'),
        ),
      ).called(1);
    },
  );

  test('initialize refusé : faux, et retenté à l’appui suivant', () async {
    initializes(false);
    expect(await service.initialize(), isFalse);
    expect(await service.initialize(), isFalse);
    verify(
      () => stt.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).called(2);
  });

  test('initialize qui lève : faux', () async {
    when(
      () => stt.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).thenThrow(Exception('plugin'));
    expect(await service.initialize(), isFalse);
  });

  test('start : options de dictée et résultats relayés', () async {
    initializes(true);
    await service.initialize();
    final results = <(String, bool)>[];
    await service.start(
      localeId: 'fr_FR',
      onResult: (text, {required isFinal}) => results.add((text, isFinal)),
      onDone: () {},
    );
    final captured = verify(
      () => stt.listen(
        onResult: captureAny(named: 'onResult'),
        listenOptions: captureAny(named: 'listenOptions'),
      ),
    ).captured;
    final options = captured[1] as SpeechListenOptions;
    expect(options.listenFor, const Duration(seconds: 60));
    expect(options.pauseFor, const Duration(seconds: 3));
    expect(options.localeId, 'fr_FR');
    expect(options.listenMode, ListenMode.dictation);
    expect(options.cancelOnError, isTrue);
    final onResult = captured[0] as void Function(SpeechRecognitionResult);
    onResult(
      SpeechRecognitionResult(const [
        SpeechRecognitionWords('Je voyage', null, 0.9),
      ], ResultType.partial.value),
    );
    onResult(
      SpeechRecognitionResult(const [
        SpeechRecognitionWords('Je voyage à Abidjan', null, 0.9),
      ], ResultType.finalResult.value),
    );
    expect(results, [('Je voyage', false), ('Je voyage à Abidjan', true)]);
  });

  test(
    'statut done et erreur permanente : fin d’écoute, une seule fois',
    () async {
      initializes(true);
      await service.initialize();
      final (onStatus, onError) = callbacks();
      var done = 0;
      await service.start(
        localeId: 'fr_FR',
        onResult: (_, {required isFinal}) {},
        onDone: () => done++,
      );
      onStatus('listening');
      expect(done, 0);
      onStatus(SpeechToText.doneStatus);
      onStatus(SpeechToText.doneStatus);
      expect(done, 1);
      await service.start(
        localeId: 'fr_FR',
        onResult: (_, {required isFinal}) {},
        onDone: () => done++,
      );
      onError(SpeechRecognitionError('error_no_match', false));
      expect(done, 1);
      onError(SpeechRecognitionError('error_permission', true));
      expect(done, 2);
    },
  );

  test(
    'deux écoutes successives : le second onDone est appelé, pas le premier',
    () async {
      initializes(true);
      await service.initialize();
      final (onStatus, _) = callbacks();
      var first = 0;
      var second = 0;
      await service.start(
        localeId: 'fr_FR',
        onResult: (_, {required isFinal}) {},
        onDone: () => first++,
      );
      await service.start(
        localeId: 'en_US',
        onResult: (_, {required isFinal}) {},
        onDone: () => second++,
      );
      onStatus(SpeechToText.doneStatus);
      expect(first, 0);
      expect(second, 1);
    },
  );

  test('stop et cancel ; après cancel, aucun onDone', () async {
    initializes(true);
    await service.initialize();
    final (onStatus, _) = callbacks();
    var done = 0;
    await service.start(
      localeId: 'fr_FR',
      onResult: (_, {required isFinal}) {},
      onDone: () => done++,
    );
    await service.stop();
    verify(() => stt.stop()).called(1);
    await service.cancel();
    verify(() => stt.cancel()).called(1);
    onStatus(SpeechToText.doneStatus);
    expect(done, 0);
  });
}
