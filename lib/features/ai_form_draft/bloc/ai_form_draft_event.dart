part of 'ai_form_draft_bloc.dart';

sealed class AiFormDraftEvent extends Equatable {
  const AiFormDraftEvent();

  @override
  List<Object?> get props => const [];
}

/// Feuille ouverte (analytics seulement).
final class AiFormDraftOpened extends AiFormDraftEvent {
  const AiFormDraftOpened();
}

/// Le micro démarre : la transcription s'affiche en direct.
final class AiFormDraftMicPressed extends AiFormDraftEvent {
  const AiFormDraftMicPressed();
}

/// Texte reconnu jusqu'ici (remplace le précédent).
final class AiFormDraftSpeechPartial extends AiFormDraftEvent {
  const AiFormDraftSpeechPartial(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// Fin d'écoute (appui sur « arrêter », silence, résultat final) : le texte
/// reconnu part comme message.
final class AiFormDraftMicStopped extends AiFormDraftEvent {
  const AiFormDraftMicStopped();
}

/// Permission refusée ou reconnaissance indisponible : saisie écrite seule.
final class AiFormDraftMicUnavailable extends AiFormDraftEvent {
  const AiFormDraftMicUnavailable();
}

final class AiFormDraftTextSubmitted extends AiFormDraftEvent {
  const AiFormDraftTextSubmitted(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

final class AiFormDraftQuickReplyTapped extends AiFormDraftEvent {
  const AiFormDraftQuickReplyTapped(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// « Réessayer » après une erreur réseau : renvoie le même tour.
final class AiFormDraftRetryRequested extends AiFormDraftEvent {
  const AiFormDraftRetryRequested();
}

/// « Corriger quelque chose » depuis le résumé.
final class AiFormDraftCorrectRequested extends AiFormDraftEvent {
  const AiFormDraftCorrectRequested();
}

/// « Remplir le formulaire » (ou « Remplir avec ce qui est compris »).
final class AiFormDraftApplyRequested extends AiFormDraftEvent {
  const AiFormDraftApplyRequested();
}
