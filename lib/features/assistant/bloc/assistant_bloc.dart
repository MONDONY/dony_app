import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/assistant/bloc/assistant_escalation.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:dony/features/assistant/data/assistant_repository.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'assistant_event.dart';
part 'assistant_state.dart';

/// À partir de ce nombre de questions restantes, l'utilisateur est prévenu
/// (2 : dès la 18e question avec la limite de 20 du back).
const int kAssistantQuotaWarnAt = 2;

/// Conversation éphémère avec l'assistant IA. Singleton de l'app : l'historique
/// survit à la fermeture de l'écran, pas au redémarrage (rien n'est persisté).
class AssistantBloc extends Bloc<AssistantEvent, AssistantState> {
  AssistantBloc(
    this._repository,
    this._support,
    this._analytics, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const AssistantState()) {
    on<AssistantStatusRequested>(_onStatus);
    on<AssistantOpened>(_onOpened);
    on<AssistantQuestionSubmitted>(_onQuestion);
    on<AssistantRetryRequested>(_onRetry);
    on<AssistantResetRequested>(_onReset);
    on<AssistantFeedbackGiven>(_onFeedback);
    on<AssistantActionTapped>(_onAction);
    on<AssistantParcelChosen>(_onParcelChosen);
    on<AssistantScreenOpened>(_onScreenOpened);
    on<AssistantEscalationRequested>(_onEscalation);
    on<AssistantSessionEnded>(_onSessionEnded);
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

  /// Intervalle minimal entre deux sondes non forcées (retour au premier plan).
  static const Duration statusInterval = Duration(minutes: 10);

  final DateTime Function() _clock;
  final AssistantRepository _repository;
  final SupportRepository _support;
  final AnalyticsService _analytics;
  int _nextId = 0;

  /// Incrémenté à chaque « Nouvelle conversation » et à chaque fin de session :
  /// une réponse qui arrive après coup pour l'ancienne conversation est
  /// écartée.
  int _epoch = 0;

  /// Incrémenté à chaque fin de session ([AssistantSessionEnded]) : une
  /// escalade ou une sonde lancée pour le compte précédent n'émet plus rien.
  /// Distinct de [_epoch] : le ticket créé reste signalé après une simple
  /// « Nouvelle conversation ».
  int _session = 0;

  bool _probing = false;
  bool _probingForced = false;

  /// Une sonde forcée est arrivée pendant une sonde non forcée : rejouée à la
  /// fin de celle-ci plutôt qu'ignorée.
  bool _forcedPending = false;
  DateTime? _lastProbeAt;

  Future<void> _onStatus(
    AssistantStatusRequested event,
    Emitter<AssistantState> emit,
  ) async {
    if (_probing) {
      if (event.force && !_probingForced) _forcedPending = true;
      return;
    }
    var force = event.force;
    _probing = true;
    try {
      while (true) {
        final last = _lastProbeAt;
        if (!force &&
            last != null &&
            _clock().difference(last) < statusInterval) {
          return;
        }
        _probingForced = force;
        await _probe(force, emit);
        if (!_forcedPending) return;
        _forcedPending = false;
        force = true;
      }
    } finally {
      _probing = false;
      _probingForced = false;
    }
  }

  Future<void> _probe(bool force, Emitter<AssistantState> emit) async {
    final session = _session;
    // Entrée en session : le résultat d'un compte précédent ne compte plus.
    if (force && state.available) emit(state.copyWith(available: false));
    bool? enabled;
    try {
      enabled = await _repository.status();
    } catch (_) {
      // La sonde ne lève jamais : tout échec vaut « inconnu ».
    }
    // Réponse pour le compte précédent : le suivant sonde de son côté.
    if (session != _session) return;
    if (enabled == null) {
      // Réseau instable, 5xx, corps illisible : on garde la valeur précédente
      // (déjà fausse pour une sonde forcée) et on n'arme pas le délai, la
      // prochaine sonde au retour au premier plan repart.
      return;
    }
    _lastProbeAt = _clock();
    // La sonde fait foi : un « éteint » appris d'une question est levé si le
    // back répond de nouveau.
    emit(state.copyWith(available: enabled, disabled: enabled ? false : null));
  }

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

  /// Ajoute l'explication de l'écran d'où vient l'utilisateur, écrite dans une
  /// fiche du back (ni IA, ni quota). Pas de doublon si la dernière réponse
  /// explique déjà cet écran. Sur la fiche d'un colis, ce colis devient le
  /// sujet de la conversation (le back revérifie l'accès à chaque question).
  Future<void> _onScreenOpened(
    AssistantScreenOpened event,
    Emitter<AssistantState> emit,
  ) async {
    if (state.disabled) return;
    final parcelId = event.parcelId;
    if (parcelId != null && parcelId.isNotEmpty && !state.isSending) {
      emit(state.copyWith(parcelId: parcelId));
    }
    final last = state.messages.isEmpty ? null : state.messages.last;
    if (last != null && last.screen == event.screen) return;
    final epoch = _epoch;
    final session = _session;
    final intro = await _repository.screen(event.screen, event.locale);
    if (epoch != _epoch || session != _session) return;
    unawaited(
      _analytics.logEvent(
        intro == null
            ? AnalyticsEvents.assistantScreenUnexplained
            : AnalyticsEvents.assistantScreenExplained,
        properties: {'screen': event.screen},
      ),
    );
    // Une question partie entre-temps : l'explication arriverait après elle.
    if (intro == null || state.isSending) return;
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          AssistantMessage(
            id: _nextId++,
            author: AssistantAuthor.assistant,
            text: intro.explanation,
            actions: intro.actions,
            suggestions: intro.questions,
            screen: event.screen,
          ),
        ],
      ),
    );
  }

  /// Repose la question qui a amené le choix, pour le colis touché. La
  /// question est le dernier message de l'utilisateur avant la réponse qui
  /// proposait ce colis.
  Future<void> _onParcelChosen(
    AssistantParcelChosen event,
    Emitter<AssistantState> emit,
  ) async {
    if (state.isSending || state.disabled) return;
    final index = state.messages.indexWhere(
      (m) => m.parcels.contains(event.choice),
    );
    if (index < 0) return;
    String? question;
    for (var i = index - 1; i >= 0 && question == null; i--) {
      final m = state.messages[i];
      if (m.author == AssistantAuthor.user) question = m.text;
    }
    if (question == null) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.assistantParcelChosen,
        properties: {
          'role': event.choice.role,
          'active': event.choice.active,
          'position': event.position,
        },
      ),
    );
    final history = _historyFrom(state.messages);
    final messages = [
      ...state.messages,
      AssistantMessage(
        id: _nextId++,
        author: AssistantAuthor.user,
        text: event.label,
      ),
    ];
    await _ask(
      question,
      event.locale,
      history,
      messages,
      emit,
      parcelId: event.choice.parcelId,
    );
  }

  /// [parcelId] : colis choisi à l'instant, sinon celui de la conversation.
  /// Gardé dans l'état dès l'envoi, pour que « Réessayer » le renvoie.
  Future<void> _ask(
    String question,
    String locale,
    List<AssistantHistoryTurn> history,
    List<AssistantMessage> messages,
    Emitter<AssistantState> emit, {
    String? parcelId,
  }) async {
    final epoch = _epoch;
    emit(
      state.copyWith(
        messages: messages,
        isSending: true,
        clearLastFailedQuestion: true,
        parcelId: parcelId,
      ),
    );
    try {
      final answer = await _repository.ask(
        question: question,
        locale: locale,
        history: history,
        parcelId: state.parcelId,
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
      if (answer.remainingToday <= kAssistantQuotaWarnAt) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.assistantQuotaWarningShown,
            properties: {'remaining': answer.remainingToday},
          ),
        );
      }
      if (answer.parcels.isNotEmpty) {
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.assistantParcelChoicesShown,
            properties: {
              'count': answer.parcels.length,
              'active_count': answer.parcels.where((p) => p.active).length,
            },
          ),
        );
      }
      emit(
        state.copyWith(
          isSending: false,
          quotaExceeded: false,
          remainingToday: answer.remainingToday,
          // La réponse fait foi : sans colis, la conversation n'en suit plus.
          parcelId: answer.parcelId,
          clearParcelId: answer.parcelId == null,
          messages: [
            ...state.messages,
            AssistantMessage(
              id: _nextId++,
              author: AssistantAuthor.assistant,
              text: answer.answer,
              actions: answer.actions,
              parcels: answer.parcels,
              answered: answer.answered,
            ),
          ],
        ),
      );
    } on AssistantQuotaExceededException {
      if (epoch != _epoch) return;
      unawaited(_analytics.logEvent(AnalyticsEvents.assistantQuotaReached));
      emit(
        state.copyWith(
          isSending: false,
          quotaExceeded: true,
          remainingToday: 0,
        ),
      );
    } on AssistantDisabledException {
      if (epoch != _epoch) return;
      emit(state.copyWith(isSending: false, disabled: true, available: false));
    } catch (error, stackTrace) {
      // Réseau, ou toute exception inattendue : jamais bloqué en isSending.
      // Le dépôt ne lève que des AssistantException : tout le reste est un
      // bug, remonté à Sentry sans changer ce que voit l'utilisateur.
      if (error is! AssistantNetworkException) {
        AppLog.error(
          'assistant: exception inattendue',
          error: error,
          stackTrace: stackTrace,
        );
      }
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

  /// Vide la conversation. La disponibilité (`available`) et « éteint »
  /// (`disabled`) ne dépendent pas de la conversation : gardés tels quels.
  void _onReset(AssistantResetRequested event, Emitter<AssistantState> emit) {
    _epoch++;
    emit(
      AssistantState(
        available: state.available,
        disabled: state.disabled,
        remainingToday: state.remainingToday,
      ),
    );
  }

  /// Repart de zéro pour le compte suivant : conversation, escalade,
  /// disponibilité, et délai de la sonde (le compte suivant sonde de nouveau).
  void _onSessionEnded(
    AssistantSessionEnded event,
    Emitter<AssistantState> emit,
  ) {
    _epoch++;
    _session++;
    _lastProbeAt = null;
    _forcedPending = false;
    emit(const AssistantState());
  }

  void _onFeedback(AssistantFeedbackGiven event, Emitter<AssistantState> emit) {
    final message = state.messages.where((m) => m.id == event.messageId);
    if (message.isEmpty) return;
    final value = event.up ? 'up' : 'down';
    // Même pouce touché de nouveau : rien ne change, rien n'est réémis.
    if (message.first.feedback == value) return;
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
    final epoch = _epoch;
    final session = _session;
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
      // Le ticket appartient au compte précédent : rien n'est signalé (ni
      // ouvert) au compte suivant.
      if (session != _session) return;
      unawaited(_analytics.logEvent(AnalyticsEvents.assistantEscalated));
      // Même après « Nouvelle conversation » : le ticket existe, l'utilisateur
      // doit pouvoir le retrouver.
      emit(
        state.copyWith(
          escalationStatus: AssistantEscalationStatus.success,
          escalatedTicketId: ticket.id,
        ),
      );
    } catch (error, stackTrace) {
      // Un échec réseau est déjà remonté par ApiClient ; le reste est un bug.
      if (error is! DioException) {
        AppLog.error(
          'assistant: escalade, exception inattendue',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (epoch != _epoch) return;
      emit(state.copyWith(escalationStatus: AssistantEscalationStatus.failure));
    }
  }
}
