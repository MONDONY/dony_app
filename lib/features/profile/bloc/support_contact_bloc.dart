import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'support_contact_event.dart';
part 'support_contact_state.dart';

class SupportContactBloc
    extends Bloc<SupportContactEvent, SupportContactState> {
  SupportContactBloc(this._analytics) : super(const SupportContactState()) {
    on<SupportCategorySelected>(_onCategorySelected);
    on<SupportSubjectChanged>(_onSubjectChanged);
    on<SupportMessageChanged>(_onMessageChanged);
    on<SupportSubmitRequested>(_onSubmitRequested);
    on<SupportEmailComposerOpened>(_onEmailComposerOpened);
    on<SupportEmailComposerFailed>(_onEmailComposerFailed);
  }

  final AnalyticsService _analytics;

  void _onCategorySelected(
    SupportCategorySelected event,
    Emitter<SupportContactState> emit,
  ) {
    emit(
      state.copyWith(
        category: event.category,
        submitStatus: SupportSubmitStatus.idle,
        clearErrorMessage: true,
      ),
    );
  }

  void _onSubjectChanged(
    SupportSubjectChanged event,
    Emitter<SupportContactState> emit,
  ) {
    emit(
      state.copyWith(
        subject: event.subject,
        submitStatus: SupportSubmitStatus.idle,
        clearErrorMessage: true,
      ),
    );
  }

  void _onMessageChanged(
    SupportMessageChanged event,
    Emitter<SupportContactState> emit,
  ) {
    emit(
      state.copyWith(
        message: event.message,
        submitStatus: SupportSubmitStatus.idle,
        clearErrorMessage: true,
      ),
    );
  }

  void _onSubmitRequested(
    SupportSubmitRequested event,
    Emitter<SupportContactState> emit,
  ) {
    if (!state.isValid) {
      return;
    }
    emit(
      state.copyWith(
        submitStatus: SupportSubmitStatus.submitting,
        clearErrorMessage: true,
      ),
    );
  }

  void _onEmailComposerOpened(
    SupportEmailComposerOpened event,
    Emitter<SupportContactState> emit,
  ) {
    if (state.submitStatus != SupportSubmitStatus.submitting) {
      return;
    }
    emit(
      state.copyWith(
        submitStatus: SupportSubmitStatus.success,
        clearErrorMessage: true,
      ),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.supportEmailComposerOpened,
        properties: {'category': state.category},
      ),
    );
  }

  void _onEmailComposerFailed(
    SupportEmailComposerFailed event,
    Emitter<SupportContactState> emit,
  ) {
    if (state.submitStatus != SupportSubmitStatus.submitting) {
      return;
    }
    emit(
      state.copyWith(
        submitStatus: SupportSubmitStatus.error,
        errorMessage: 'Impossible d\'ouvrir l\'application Mail.',
      ),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.supportContactFailed,
        properties: {'category': state.category, 'reason': event.reason},
      ),
    );
  }
}
