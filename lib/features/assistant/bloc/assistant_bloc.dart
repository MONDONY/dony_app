import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/assistant/bloc/assistant_escalation.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:dony/features/assistant/data/assistant_repository.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'assistant_event.dart';
part 'assistant_state.dart';

/// Conversation éphémère avec l'assistant IA. Singleton de l'app : l'historique
/// survit à la fermeture de l'écran, pas au redémarrage (rien n'est persisté).
class AssistantBloc extends Bloc<AssistantEvent, AssistantState> {
  AssistantBloc(this._repository, this._support, this._analytics)
    : super(const AssistantState()) {
    on<AssistantOpened>(_onOpened);
    on<AssistantQuestionSubmitted>(_onQuestion);
    on<AssistantRetryRequested>(_onRetry);
    on<AssistantResetRequested>(_onReset);
    on<AssistantFeedbackGiven>(_onFeedback);
    on<AssistantActionTapped>(_onAction);
    on<AssistantEscalationRequested>(_onEscalation);
    on<AssistantEscalationHandled>(
      (_, emit) => emit(
        state.copyWith(
          escalationStatus: AssistantEscalationStatus.idle,
          clearEscalatedTicketId: true,
        ),
      ),
    );
  }

  /// Nombre maximal de tours envoyés au back comme contexte.
  static const int _historyTurns = 12;

  final AssistantRepository _repository;
  final SupportRepository _support;
  final AnalyticsService _analytics;
  int _nextId = 0;

  /// Incrémenté à chaque « Nouvelle conversation » : une réponse qui arrive
  /// après coup pour l'ancienne conversation est écartée.
  int _epoch = 0;

  void _onOpened(AssistantOpened event, Emitter<AssistantState> emit) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.assistantOpened,
        properties: {'source': event.source},
      ),
    );
  }

  Future<void> _onQuestion(
    AssistantQuestionSubmitted event,
    Emitter<AssistantState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty || state.isSending || state.disabled) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.assistantQuestionAsked,
        properties: {
          'locale': event.locale,
          'suggestion': event.fromSuggestion,
        },
      ),
    );
    final history = _historyFrom(state.messages);
    final messages = [
      ...state.messages,
      AssistantMessage(id: _nextId++, author: AssistantAuthor.user, text: text),
    ];
    await _ask(text, event.locale, history, messages, emit);
  }

  Future<void> _onRetry(
    AssistantRetryRequested event,
    Emitter<AssistantState> emit,
  ) async {
    final question = state.lastFailedQuestion;
    if (question == null || state.isSending || state.disabled) return;
    // La question est déjà dans la conversation : on retire seulement le
    // message d'erreur et on l'exclut de l'historique envoyé.
    final messages = state.messages.where((m) => !m.isError).toList();
    final history = _historyFrom(messages.sublist(0, messages.length - 1));
    await _ask(question, event.locale, history, messages, emit);
  }

  List<AssistantHistoryTurn> _historyFrom(List<AssistantMessage> messages) {
    final turns = [
      for (final m in messages)
        if (!m.isError)
          AssistantHistoryTurn(
            role: m.author == AssistantAuthor.user ? 'user' : 'assistant',
            text: m.text,
          ),
    ];
    return turns.length > _historyTurns
        ? turns.sublist(turns.length - _historyTurns)
        : turns;
  }

  Future<void> _ask(
    String question,
    String locale,
    List<AssistantHistoryTurn> history,
    List<AssistantMessage> messages,
    Emitter<AssistantState> emit,
  ) async {
    final epoch = _epoch;
    emit(
      state.copyWith(
        messages: messages,
        isSending: true,
        clearLastFailedQuestion: true,
      ),
    );
    try {
      final answer = await _repository.ask(
        question: question,
        locale: locale,
        history: history,
      );
      if (epoch != _epoch) return;
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.assistantAnswerReceived,
          properties: {
            'answered': answer.answered,
            'provider': answer.provider,
            'actions_count': answer.actions.length,
          },
        ),
      );
      emit(
        state.copyWith(
          isSending: false,
          messages: [
            ...state.messages,
            AssistantMessage(
              id: _nextId++,
              author: AssistantAuthor.assistant,
              text: answer.answer,
              actions: answer.actions,
              answered: answer.answered,
            ),
          ],
        ),
      );
    } on AssistantQuotaExceededException {
      if (epoch != _epoch) return;
      unawaited(_analytics.logEvent(AnalyticsEvents.assistantQuotaReached));
      emit(state.copyWith(isSending: false, quotaExceeded: true));
    } on AssistantDisabledException {
      if (epoch != _epoch) return;
      emit(state.copyWith(isSending: false, disabled: true));
    } catch (_) {
      // Réseau, ou toute exception inattendue : jamais bloqué en isSending.
      if (epoch != _epoch) return;
      emit(
        state.copyWith(
          isSending: false,
          lastFailedQuestion: question,
          messages: [
            ...state.messages,
            AssistantMessage(
              id: _nextId++,
              author: AssistantAuthor.assistant,
              text: '',
              isError: true,
            ),
          ],
        ),
      );
    }
  }

  void _onReset(AssistantResetRequested event, Emitter<AssistantState> emit) {
    _epoch++;
    emit(const AssistantState());
  }

  void _onFeedback(AssistantFeedbackGiven event, Emitter<AssistantState> emit) {
    if (!state.messages.any((m) => m.id == event.messageId)) return;
    final value = event.up ? 'up' : 'down';
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.assistantFeedback,
        properties: {'value': value},
      ),
    );
    emit(
      state.copyWith(
        messages: [
          for (final m in state.messages)
            m.id == event.messageId ? m.copyWith(feedback: value) : m,
        ],
      ),
    );
  }

  void _onAction(AssistantActionTapped event, Emitter<AssistantState> emit) {
    unawaited(
      _analytics.logEvent(
        event.matched
            ? AnalyticsEvents.assistantActionTapped
            : AnalyticsEvents.assistantActionUnmatched,
        properties: {'route': event.route},
      ),
    );
  }

  Future<void> _onEscalation(
    AssistantEscalationRequested event,
    Emitter<AssistantState> emit,
  ) async {
    if (state.escalationStatus == AssistantEscalationStatus.sending) return;
    emit(state.copyWith(escalationStatus: AssistantEscalationStatus.sending));
    final l = AppL10n.current;
    try {
      final subject = buildEscalationSubject(state.messages);
      final message = buildEscalationMessage(
        state.messages,
        youLabel: l.assistantTranscriptYou,
        assistantLabel: l.assistantTranscriptAssistant,
        header: l.assistantTranscriptHeader,
      );
      final ticket = await _support.createTicket(
        category: 'OTHER',
        subject: subject.isEmpty
            ? l.assistantEscalationDefaultSubject
            : subject,
        message: message.isEmpty ? null : message,
      );
      unawaited(_analytics.logEvent(AnalyticsEvents.assistantEscalated));
      emit(
        state.copyWith(
          escalationStatus: AssistantEscalationStatus.success,
          escalatedTicketId: ticket.id,
        ),
      );
    } catch (_) {
      emit(state.copyWith(escalationStatus: AssistantEscalationStatus.failure));
    }
  }
}
