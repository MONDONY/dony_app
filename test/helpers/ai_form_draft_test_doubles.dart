import 'package:dony/features/ai_form_draft/data/speech_service.dart';

/// Dictée simulée : [emit] et [finish] jouent le rôle du plugin.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.available = true});

  bool available;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? lastLocaleId;
  SpeechResultCallback? _onResult;
  void Function()? _onDone;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> start({
    required String localeId,
    required SpeechResultCallback onResult,
    required void Function() onDone,
  }) async {
    startCount++;
    lastLocaleId = localeId;
    _onResult = onResult;
    _onDone = onDone;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    _onDone = null;
  }

  void emit(String text, {bool isFinal = false}) =>
      _onResult?.call(text, isFinal: isFinal);

  void finish() => _onDone?.call();
}
