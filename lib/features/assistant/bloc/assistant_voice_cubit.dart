import 'dart:async';

import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AssistantVoiceStatus {
  /// Micro prêt.
  idle,

  /// Demande de permission ou démarrage de la dictée en cours.
  starting,

  /// Le téléphone écoute : le texte reconnu arrive dans [transcript].
  listening,

  /// Permission refusée ou reconnaissance indisponible : écrit seulement.
  unavailable,
}

final class AssistantVoiceState extends Equatable {
  const AssistantVoiceState({
    this.status = AssistantVoiceStatus.idle,
    this.transcript = '',
    this.completed = 0,
    this.completedText = '',
  });

  final AssistantVoiceStatus status;

  /// Texte reconnu pendant l'écoute (partiel puis final).
  final String transcript;

  /// Incrémenté à chaque dictée terminée avec du texte : l'écran envoie alors
  /// [completedText] comme une question tapée.
  final int completed;
  final String completedText;

  bool get listening => status == AssistantVoiceStatus.listening;

  bool get busy =>
      status == AssistantVoiceStatus.listening ||
      status == AssistantVoiceStatus.starting;

  AssistantVoiceState copyWith({
    AssistantVoiceStatus? status,
    String? transcript,
    int? completed,
    String? completedText,
  }) => AssistantVoiceState(
    status: status ?? this.status,
    transcript: transcript ?? this.transcript,
    completed: completed ?? this.completed,
    completedText: completedText ?? this.completedText,
  );

  @override
  List<Object?> get props => [status, transcript, completed, completedText];
}

/// Dictée de l'écran de l'assistant (FLUTTER-RE). La voix devient du texte sur
/// le téléphone ([SpeechService], partagé avec « Créer avec l'IA ») ; la
/// question dictée part ensuite par le même chemin qu'une question tapée.
///
/// Une instance par écran : la dictée s'arrête à la fermeture.
class AssistantVoiceCubit extends Cubit<AssistantVoiceState> {
  AssistantVoiceCubit(this._speech) : super(const AssistantVoiceState());

  final SpeechService _speech;

  /// Écoute en cours : l'arrête et envoie. Sinon : démarre.
  Future<void> toggle({required String localeId}) =>
      state.listening ? stop() : start(localeId: localeId);

  Future<void> start({required String localeId}) async {
    if (state.busy) return;
    emit(state.copyWith(status: AssistantVoiceStatus.starting, transcript: ''));
    final available = await _speech.initialize();
    if (isClosed) return;
    if (!available) {
      emit(state.copyWith(status: AssistantVoiceStatus.unavailable));
      return;
    }
    emit(state.copyWith(status: AssistantVoiceStatus.listening));
    try {
      await _speech.start(
        localeId: localeId,
        onResult: (text, {required isFinal}) {
          if (isClosed || !state.listening) return;
          emit(state.copyWith(transcript: text));
          if (isFinal) _finish();
        },
        onDone: _finish,
      );
    } on Object {
      if (!isClosed) {
        emit(state.copyWith(status: AssistantVoiceStatus.unavailable));
      }
    }
  }

  Future<void> stop() async {
    if (!state.listening) return;
    await _speech.stop();
    _finish();
  }

  void _finish() {
    if (isClosed || !state.listening) return;
    final text = state.transcript.trim();
    emit(
      text.isEmpty
          ? state.copyWith(status: AssistantVoiceStatus.idle, transcript: '')
          : state.copyWith(
              status: AssistantVoiceStatus.idle,
              transcript: '',
              completed: state.completed + 1,
              completedText: text,
            ),
    );
  }

  @override
  Future<void> close() {
    unawaited(_speech.cancel());
    return super.close();
  }
}
