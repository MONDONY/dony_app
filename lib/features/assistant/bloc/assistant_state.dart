part of 'assistant_bloc.dart';

enum AssistantAuthor { user, assistant }

class AssistantMessage extends Equatable {
  const AssistantMessage({
    required this.id,
    required this.author,
    required this.text,
    this.actions = const [],
    this.answered = true,
    this.feedback,
    this.isError = false,
  });

  final int id;
  final AssistantAuthor author;
  final String text;
  final List<AssistantAction> actions;
  final bool answered;

  /// `up` ou `down`, `null` tant que l'utilisateur n'a pas voté.
  final String? feedback;

  /// Message de panne affiché à la place d'une réponse, avec « Réessayer ».
  /// Jamais envoyé au back ni inclus dans le ticket.
  final bool isError;

  AssistantMessage copyWith({String? feedback}) => AssistantMessage(
    id: id,
    author: author,
    text: text,
    actions: actions,
    answered: answered,
    feedback: feedback ?? this.feedback,
    isError: isError,
  );

  @override
  List<Object?> get props => [
    id,
    author,
    text,
    actions,
    answered,
    feedback,
    isError,
  ];
}

enum AssistantEscalationStatus { idle, sending, success, failure }

final class AssistantState extends Equatable {
  const AssistantState({
    this.messages = const [],
    this.isSending = false,
    this.quotaExceeded = false,
    this.disabled = false,
    this.available = false,
    this.escalationStatus = AssistantEscalationStatus.idle,
    this.escalatedTicketId,
    this.lastFailedQuestion,
  });

  final List<AssistantMessage> messages;
  final bool isSending;
  final bool quotaExceeded;
  final bool disabled;

  /// Résultat de la sonde `GET /assistant/status` : `false` tant qu'elle n'a
  /// pas répondu `enabled: true` (bulle et icône cachées par défaut).
  final bool available;
  final AssistantEscalationStatus escalationStatus;
  final String? escalatedTicketId;

  /// Dernière question restée sans réponse, rejouée par « Réessayer ».
  final String? lastFailedQuestion;

  bool get isEmpty => messages.isEmpty;

  AssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? isSending,
    bool? quotaExceeded,
    bool? disabled,
    bool? available,
    AssistantEscalationStatus? escalationStatus,
    String? escalatedTicketId,
    String? lastFailedQuestion,
    bool clearEscalatedTicketId = false,
    bool clearLastFailedQuestion = false,
  }) => AssistantState(
    messages: messages ?? this.messages,
    isSending: isSending ?? this.isSending,
    quotaExceeded: quotaExceeded ?? this.quotaExceeded,
    disabled: disabled ?? this.disabled,
    available: available ?? this.available,
    escalationStatus: escalationStatus ?? this.escalationStatus,
    escalatedTicketId: clearEscalatedTicketId
        ? null
        : (escalatedTicketId ?? this.escalatedTicketId),
    lastFailedQuestion: clearLastFailedQuestion
        ? null
        : (lastFailedQuestion ?? this.lastFailedQuestion),
  );

  @override
  List<Object?> get props => [
    messages,
    isSending,
    quotaExceeded,
    disabled,
    available,
    escalationStatus,
    escalatedTicketId,
    lastFailedQuestion,
  ];
}
