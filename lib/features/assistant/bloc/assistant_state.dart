part of 'assistant_bloc.dart';

enum AssistantAuthor { user, assistant }

class AssistantMessage extends Equatable {
  const AssistantMessage({
    required this.id,
    required this.author,
    required this.text,
    this.richText,
    this.actions = const [],
    this.parcels = const [],
    this.suggestions = const [],
    this.nextQuestions = const [],
    this.screen,
    this.answered = true,
    this.feedback,
    this.isError = false,
  });

  final int id;
  final AssistantAuthor author;

  /// Texte brut : historique envoyé au back, ticket d'escalade.
  final String text;

  /// Même texte en riche (`**gras**`, puces `- `), seulement pour l'affichage.
  final String? richText;

  /// Texte à afficher : riche s'il existe, sinon brut.
  String get displayText => richText ?? text;

  final List<AssistantAction> actions;

  /// Colis proposés au choix sous la réponse (question sur l'un des siens).
  final List<AssistantParcelChoice> parcels;

  /// Questions à toucher sous l'explication d'un écran.
  final List<String> suggestions;

  /// Questions de suite et découverte proposées par le back sous une réponse.
  /// Affichées sous la dernière réponse seulement.
  final List<AssistantSuggestion> nextQuestions;

  /// Écran (motif de route) qu'explique ce message, s'il en explique un.
  final String? screen;
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
    richText: richText,
    actions: actions,
    parcels: parcels,
    suggestions: suggestions,
    nextQuestions: nextQuestions,
    screen: screen,
    answered: answered,
    feedback: feedback ?? this.feedback,
    isError: isError,
  );

  @override
  List<Object?> get props => [
    id,
    author,
    text,
    richText,
    actions,
    parcels,
    suggestions,
    nextQuestions,
    screen,
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
    this.parcelId,
    this.remainingToday,
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

  /// Colis dont parle la conversation, renvoyé au back avec chaque question
  /// tant que ses réponses le confirment. Jamais gardé hors de la conversation.
  final String? parcelId;

  /// Questions encore permises aujourd'hui, lu dans la dernière réponse du
  /// back ; `null` avant la première. Jamais affiché tel quel : sert à
  /// prévenir à l'approche de la limite. Gardé après « Nouvelle
  /// conversation » : la limite est par jour, pas par conversation.
  final int? remainingToday;

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
    String? parcelId,
    int? remainingToday,
    bool clearEscalatedTicketId = false,
    bool clearLastFailedQuestion = false,
    bool clearParcelId = false,
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
    parcelId: clearParcelId ? null : (parcelId ?? this.parcelId),
    remainingToday: remainingToday ?? this.remainingToday,
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
    parcelId,
    remainingToday,
  ];
}
