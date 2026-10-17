part of 'ai_form_draft_bloc.dart';

enum AiFormDraftStatus {
  idle,
  listening,
  sending,
  asking,
  ready,
  degraded,
  quotaExceeded,
  error,

  /// « Remplir » touché : la feuille se ferme avec [AiFormDraftState.resolved].
  applied,
}

class AiFormDraftState extends Equatable {
  const AiFormDraftState({
    required this.kind,
    this.status = AiFormDraftStatus.idle,
    this.messages = const [],
    this.draft = const {},
    this.understood = const [],
    this.missing = const [],
    this.turns = 0,
    this.partialText = '',
    this.question,
    this.quickReplies = const [],
    this.resolved,
    this.turnLimitReached = false,
    this.micUnavailable = false,
    this.correcting = false,
    this.retryAfter,
  });

  final AiFormKind kind;
  final AiFormDraftStatus status;

  /// Dialogue complet, renvoyé au serveur à chaque tour. Le message d'accueil
  /// n'en fait pas partie : il est affiché par la feuille seulement.
  final List<AiChatMessage> messages;
  final Map<String, Object?> draft;
  final List<String> understood;
  final List<String> missing;

  /// Messages `user` envoyés.
  final int turns;

  /// Transcription en cours (état `listening`).
  final String partialText;
  final String? question;
  final List<String> quickReplies;

  /// Brouillon contrôlé par l'app, calculé à l'entrée dans `ready` ou au
  /// « Remplir avec ce qui est compris ».
  final AiResolvedDraft? resolved;
  final bool turnLimitReached;
  final bool micUnavailable;

  /// « Corriger quelque chose » : la feuille affiche « Que voulez-vous corriger ? ».
  final bool correcting;
  final Duration? retryAfter;

  /// Un message peut partir : rien n'est en cours.
  bool get canTalk =>
      status == AiFormDraftStatus.idle || status == AiFormDraftStatus.asking;

  /// L'IA a compris au moins un champ.
  bool get hasDraft => draft.values.any(isFilledDraftValue);

  AiFormDraftStatus get _restingStatus =>
      messages.isEmpty ? AiFormDraftStatus.idle : AiFormDraftStatus.asking;

  AiFormDraftState copyWith({
    AiFormDraftStatus? status,
    List<AiChatMessage>? messages,
    Map<String, Object?>? draft,
    List<String>? understood,
    List<String>? missing,
    int? turns,
    String? partialText,
    String? question,
    bool clearQuestion = false,
    List<String>? quickReplies,
    AiResolvedDraft? resolved,
    bool clearResolved = false,
    bool? turnLimitReached,
    bool? micUnavailable,
    bool? correcting,
    Duration? retryAfter,
  }) => AiFormDraftState(
    kind: kind,
    status: status ?? this.status,
    messages: messages ?? this.messages,
    draft: draft ?? this.draft,
    understood: understood ?? this.understood,
    missing: missing ?? this.missing,
    turns: turns ?? this.turns,
    partialText: partialText ?? this.partialText,
    question: clearQuestion ? null : (question ?? this.question),
    quickReplies: quickReplies ?? this.quickReplies,
    resolved: clearResolved ? null : (resolved ?? this.resolved),
    turnLimitReached: turnLimitReached ?? this.turnLimitReached,
    micUnavailable: micUnavailable ?? this.micUnavailable,
    correcting: correcting ?? this.correcting,
    retryAfter: retryAfter ?? this.retryAfter,
  );

  @override
  List<Object?> get props => [
    kind,
    status,
    messages,
    draft,
    understood,
    missing,
    turns,
    partialText,
    question,
    quickReplies,
    resolved,
    turnLimitReached,
    micUnavailable,
    correcting,
    retryAfter,
  ];
}
