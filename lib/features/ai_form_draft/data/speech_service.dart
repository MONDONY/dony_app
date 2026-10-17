import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Texte reconnu : [isFinal] vaut vrai pour le dernier résultat d'une écoute.
typedef SpeechResultCallback =
    void Function(String text, {required bool isFinal});

/// Dictée du téléphone : la voix devient du texte sur l'appareil (aucune
/// transcription côté serveur). Injectable pour les tests.
abstract interface class SpeechService {
  /// Demande la permission au premier appel. Faux : micro refusé ou
  /// reconnaissance indisponible, seule la saisie écrite reste.
  Future<bool> initialize();

  Future<void> start({
    required String localeId,
    required SpeechResultCallback onResult,
    required void Function() onDone,
  });

  Future<void> stop();

  /// Arrête sans résultat et oublie le rappel de fin.
  Future<void> cancel();
}

/// Enveloppe de `speech_to_text`.
///
/// **Un seul exemplaire pour toute l'app** (`registerLazySingleton`) :
/// `SpeechToText()` est un singleton du plugin, dont `initialize` revient tout
/// de suite après un premier succès, sans réenregistrer `onStatus`/`onError`.
/// Une seconde enveloppe ne verrait donc jamais la fin d'une écoute. Le rappel
/// de fin est remplacé à chaque [start].
class SttSpeechService implements SpeechService {
  SttSpeechService([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  /// Écoute de 60 s au plus, arrêt après 3 s de silence (spec §4.4).
  static const Duration listenFor = Duration(seconds: 60);
  static const Duration pauseFor = Duration(seconds: 3);

  final SpeechToText _speech;
  void Function()? _onDone;
  bool _available = false;

  @override
  Future<bool> initialize() async {
    if (_available) return true;
    try {
      _available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
    } on Object {
      _available = false;
    }
    return _available;
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus) _finish();
  }

  void _onError(SpeechRecognitionError error) {
    if (error.permanent) _finish();
  }

  void _finish() {
    final done = _onDone;
    _onDone = null;
    done?.call();
  }

  @override
  Future<void> start({
    required String localeId,
    required SpeechResultCallback onResult,
    required void Function() onDone,
  }) async {
    _onDone = onDone;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) =>
          onResult(result.recognizedWords, isFinal: result.finalResult),
      listenOptions: SpeechListenOptions(
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() {
    _onDone = null;
    return _speech.cancel();
  }
}
