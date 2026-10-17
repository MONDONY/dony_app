import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'ai_form_draft_event.dart';
part 'ai_form_draft_state.dart';

/// Dialogue « Créer avec l'IA ». Une instance par feuille (factory GetIt) : le
/// dialogue est perdu à la fermeture, sans brouillon local (spec §5).
class AiFormDraftBloc extends Bloc<AiFormDraftEvent, AiFormDraftState> {
  AiFormDraftBloc(
    this._repository,
    this._analytics, {
    required AiFormDraftSession session,
    DateTime Function()? clock,
    String Function()? locale,
  }) : _session = session,
       _clock = clock ?? DateTime.now,
       _locale = locale ?? (() => AppL10n.localeName),
       super(AiFormDraftState(kind: session.kind)) {
    on<AiFormDraftOpened>((_, _) => _log(AnalyticsEvents.aiFormDraftOpened));
    on<AiFormDraftMicPressed>(_onMicPressed);
    on<AiFormDraftSpeechPartial>(_onSpeechPartial);
    on<AiFormDraftMicStopped>(_onMicStopped);
    on<AiFormDraftMicUnavailable>(_onMicUnavailable);
    on<AiFormDraftTextSubmitted>((e, emit) => _submitIfAllowed(e.text, emit));
    on<AiFormDraftQuickReplyTapped>(
      (e, emit) => _submitIfAllowed(e.text, emit),
    );
    on<AiFormDraftRetryRequested>(_onRetry);
    on<AiFormDraftCorrectRequested>(_onCorrect);
    on<AiFormDraftApplyRequested>(_onApply);
  }

  /// Messages `user` par dialogue (miroir de `form-draft.max-turns`).
  static const int maxTurns = 8;

  /// Longueur maximale d'un message accepté par le serveur.
  static const int maxMessageLength = 1000;

  // `asking` : « Remplir avec ce qui est compris » pendant le dialogue, pour
  // corriger un seul champ après « Reparler » sans tout redire.
  static const _applicable = {
    AiFormDraftStatus.asking,
    AiFormDraftStatus.ready,
    AiFormDraftStatus.degraded,
    AiFormDraftStatus.quotaExceeded,
    AiFormDraftStatus.error,
  };

  final AiFormDraftRepository _repository;
  final AnalyticsService _analytics;
  final AiFormDraftSession _session;

  /// Devise du formulaire à l'ouverture : celle du résumé et des puces quand
  /// l'IA n'en a pas dit.
  String? get defaultCurrency => _session.defaultCurrency;
  final DateTime Function() _clock;
  final String Function() _locale;
  bool _applying = false;

  void _onMicPressed(
    AiFormDraftMicPressed event,
    Emitter<AiFormDraftState> emit,
  ) {
    if (!state.canTalk) return;
    emit(state.copyWith(status: AiFormDraftStatus.listening, partialText: ''));
  }

  void _onSpeechPartial(
    AiFormDraftSpeechPartial event,
    Emitter<AiFormDraftState> emit,
  ) {
    if (state.status != AiFormDraftStatus.listening) return;
    emit(state.copyWith(partialText: event.text));
  }

  Future<void> _onMicStopped(
    AiFormDraftMicStopped event,
    Emitter<AiFormDraftState> emit,
  ) async {
    if (state.status != AiFormDraftStatus.listening) return;
    final text = state.partialText.trim();
    if (text.isEmpty) {
      emit(state.copyWith(status: state._restingStatus, partialText: ''));
      return;
    }
    _log(AnalyticsEvents.aiFormDraftVoiceUsed);
    await _submit(text, emit);
  }

  void _onMicUnavailable(
    AiFormDraftMicUnavailable event,
    Emitter<AiFormDraftState> emit,
  ) {
    emit(
      state.copyWith(
        micUnavailable: true,
        partialText: '',
        status: state.status == AiFormDraftStatus.listening
            ? state._restingStatus
            : state.status,
      ),
    );
  }

  Future<void> _submitIfAllowed(
    String raw,
    Emitter<AiFormDraftState> emit,
  ) async {
    if (!state.canTalk) return;
    final text = raw.trim();
    if (text.isEmpty) return;
    await _submit(text, emit);
  }

  Future<void> _submit(String text, Emitter<AiFormDraftState> emit) async {
    final clipped = text.length > maxMessageLength
        ? text.substring(0, maxMessageLength)
        : text;
    emit(
      state.copyWith(
        status: AiFormDraftStatus.sending,
        messages: [...state.messages, AiChatMessage.user(clipped)],
        turns: state.turns + 1,
        partialText: '',
        quickReplies: const [],
        clearQuestion: true,
        correcting: false,
      ),
    );
    await _send(emit);
  }

  Future<void> _onRetry(
    AiFormDraftRetryRequested event,
    Emitter<AiFormDraftState> emit,
  ) async {
    if (state.status != AiFormDraftStatus.error) return;
    emit(state.copyWith(status: AiFormDraftStatus.sending));
    await _send(emit);
  }

  Future<void> _send(Emitter<AiFormDraftState> emit) async {
    final AiFormDraftReply reply;
    try {
      reply = await _repository.send(
        kind: state.kind,
        messages: state.messages,
        draft: state.draft,
        locale: _locale(),
        now: _clock(),
        defaultCurrency: _session.defaultCurrency,
      );
    } on AiFormDraftQuotaExceededException catch (e) {
      _log(AnalyticsEvents.aiFormDraftQuotaExceeded);
      emit(
        state.copyWith(
          status: AiFormDraftStatus.quotaExceeded,
          retryAfter: e.retryAfter,
        ),
      );
      return;
    } on AiFormDraftTooManyTurnsException {
      await _emitReady(emit, state, turnLimitReached: true);
      return;
    } on AiFormDraftDisabledException {
      _log(AnalyticsEvents.aiFormDraftDegraded);
      emit(state.copyWith(status: AiFormDraftStatus.degraded));
      return;
    } on Object {
      emit(state.copyWith(status: AiFormDraftStatus.error));
      return;
    }
    final question = reply.question;
    final updated = state.copyWith(
      draft: reply.draft,
      understood: reply.understood,
      missing: reply.missing,
      messages: question == null
          ? null
          : [...state.messages, AiChatMessage.assistant(question)],
      question: question,
      clearQuestion: question == null,
      quickReplies: reply.quickReplies,
    );
    _log(AnalyticsEvents.aiFormDraftTurn, {
      'turns': updated.turns,
      'missing_count': reply.missing.length,
    });
    if (reply.degraded) {
      _log(AnalyticsEvents.aiFormDraftDegraded);
      emit(
        updated.copyWith(
          status: AiFormDraftStatus.degraded,
          clearQuestion: true,
          quickReplies: const [],
        ),
      );
      return;
    }
    if (reply.done) {
      await _emitReady(emit, updated);
      return;
    }
    if (updated.turns >= maxTurns) {
      await _emitReady(emit, updated, turnLimitReached: true);
      return;
    }
    emit(updated.copyWith(status: AiFormDraftStatus.asking));
  }

  Future<void> _emitReady(
    Emitter<AiFormDraftState> emit,
    AiFormDraftState from, {
    bool turnLimitReached = false,
  }) async {
    final resolved = await _session.resolver.resolve(from.draft);
    _log(AnalyticsEvents.aiFormDraftReady, {
      'turns': from.turns,
      'turn_limit': turnLimitReached,
    });
    emit(
      from.copyWith(
        status: AiFormDraftStatus.ready,
        resolved: resolved,
        turnLimitReached: turnLimitReached,
        clearQuestion: true,
        quickReplies: const [],
        correcting: false,
      ),
    );
  }

  void _onCorrect(
    AiFormDraftCorrectRequested event,
    Emitter<AiFormDraftState> emit,
  ) {
    if (state.status != AiFormDraftStatus.ready) return;
    emit(
      state.copyWith(
        status: AiFormDraftStatus.asking,
        correcting: true,
        clearResolved: true,
        turnLimitReached: false,
      ),
    );
  }

  Future<void> _onApply(
    AiFormDraftApplyRequested event,
    Emitter<AiFormDraftState> emit,
  ) async {
    if (_applying || !_applicable.contains(state.status)) return;
    if (state.resolved == null && !state.hasDraft) return;
    _applying = true;
    try {
      final resolved =
          state.resolved ?? await _session.resolver.resolve(state.draft);
      _log(AnalyticsEvents.aiFormDraftApplied, {
        'fields_count': resolved.filledFields.length,
      });
      emit(
        state.copyWith(status: AiFormDraftStatus.applied, resolved: resolved),
      );
    } finally {
      _applying = false;
    }
  }

  void _log(String name, [Map<String, Object> extra = const {}]) {
    unawaited(
      _analytics.logEvent(
        name,
        properties: {'kind': state.kind.analyticsName, ...extra},
      ),
    );
  }
}
