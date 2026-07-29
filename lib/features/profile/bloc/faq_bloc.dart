import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'faq_event.dart';
part 'faq_state.dart';

class FaqBloc extends Bloc<FaqEvent, FaqState> {
  FaqBloc(this._analytics) : super(const FaqState()) {
    on<FaqSearchChanged>(_onSearchChanged);
    on<FaqQuestionOpened>(_onQuestionOpened);
    on<FaqContactRequested>(_onContactRequested);
  }

  final AnalyticsService _analytics;

  void _onSearchChanged(FaqSearchChanged event, Emitter<FaqState> emit) {
    emit(state.copyWith(query: event.query));
  }

  void _onQuestionOpened(FaqQuestionOpened event, Emitter<FaqState> emit) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.faqQuestionOpened,
        properties: {
          'category': event.categoryId,
          'question_id': event.questionId,
        },
      ),
    );
  }

  void _onContactRequested(FaqContactRequested event, Emitter<FaqState> emit) {
    unawaited(_analytics.logEvent(AnalyticsEvents.faqContactRequested));
  }
}
