part of 'assistant_bloc.dart';

sealed class AssistantEvent extends Equatable {
  const AssistantEvent();

  @override
  List<Object?> get props => const [];
}

/// Écran de l'assistant ouvert. [source] : `bubble` ou `messages_header`.
final class AssistantOpened extends AssistantEvent {
  const AssistantOpened(this.source);

  final String source;

  @override
  List<Object?> get props => [source];
}

final class AssistantQuestionSubmitted extends AssistantEvent {
  const AssistantQuestionSubmitted(
    this.text, {
    required this.locale,
    this.fromSuggestion = false,
  });

  final String text;
  final String locale;
  final bool fromSuggestion;

  @override
  List<Object?> get props => [text, locale, fromSuggestion];
}

/// Renvoie la dernière question restée sans réponse (erreur réseau).
final class AssistantRetryRequested extends AssistantEvent {
  const AssistantRetryRequested({required this.locale});

  final String locale;

  @override
  List<Object?> get props => [locale];
}

/// « Nouvelle conversation » : vide l'historique en mémoire.
final class AssistantResetRequested extends AssistantEvent {
  const AssistantResetRequested();
}

final class AssistantFeedbackGiven extends AssistantEvent {
  const AssistantFeedbackGiven(this.messageId, {required this.up});

  final int messageId;
  final bool up;

  @override
  List<Object?> get props => [messageId, up];
}

/// Tap sur une action proposée. [matched] : la route correspond à un écran
/// connu de l'app (sinon `assistant_action_unmatched`).
final class AssistantActionTapped extends AssistantEvent {
  const AssistantActionTapped(this.route, {required this.matched});

  final String route;
  final bool matched;

  @override
  List<Object?> get props => [route, matched];
}

/// « Parler à un humain » : crée un ticket support avec l'échange.
final class AssistantEscalationRequested extends AssistantEvent {
  const AssistantEscalationRequested();
}

/// L'UI a consommé le résultat de l'escalade (succès ou échec).
final class AssistantEscalationHandled extends AssistantEvent {
  const AssistantEscalationHandled();
}

/// Sonde de disponibilité. [force] : à l'entrée en session (réinitialise
/// `available`) ; sinon (retour au premier plan) au plus une fois par
/// [AssistantBloc.statusInterval].
final class AssistantStatusRequested extends AssistantEvent {
  const AssistantStatusRequested({this.force = true});

  final bool force;

  @override
  List<Object?> get props => [force];
}

/// Fin de la session du compte (déconnexion, compte supprimé, session invitée,
/// changement de compte) : la conversation, une réponse ou une escalade en vol
/// et le résultat de la sonde ne passent jamais au compte suivant. Pas envoyé
/// pour un verrou PIN (même compte).
final class AssistantSessionEnded extends AssistantEvent {
  const AssistantSessionEnded();
}
