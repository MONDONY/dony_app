import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/data/activation_repository.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Choix « Autre » : envoyé au serveur comme destination absente.
const String kIntentOtherDestination = 'OTHER';

enum IntentFormStatus { editing, saving, saved, error }

class IntentFormState extends Equatable {
  const IntentFormState({
    this.intent,
    this.destination,
    this.status = IntentFormStatus.editing,
  });

  final UserIntent? intent;
  final String? destination;
  final IntentFormStatus status;

  bool get isValid => intent != null && destination != null;

  String? get destinationForApi =>
      destination == kIntentOtherDestination ? null : destination;

  IntentFormState copyWith({
    UserIntent? intent,
    String? destination,
    IntentFormStatus? status,
  }) => IntentFormState(
    intent: intent ?? this.intent,
    destination: destination ?? this.destination,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [intent, destination, status];
}

/// Formulaire « Vous utilisez Yadony pour… » (inscription, sheet, réglages).
class IntentCubit extends Cubit<IntentFormState> {
  IntentCubit(
    this._repository,
    this._analytics, {
    UserIntent? initialIntent,
    String? initialDestination,
  }) : super(
         IntentFormState(
           intent: initialIntent,
           destination: initialDestination,
         ),
       );

  final ActivationRepository _repository;
  final AnalyticsService _analytics;

  void selectIntent(UserIntent intent) =>
      emit(state.copyWith(intent: intent, status: IntentFormStatus.editing));

  void selectDestination(String code) =>
      emit(state.copyWith(destination: code, status: IntentFormStatus.editing));

  Future<void> submit(IntentSource source) async {
    final intent = state.intent;
    if (!state.isValid ||
        intent == null ||
        state.status == IntentFormStatus.saving) {
      return;
    }
    emit(state.copyWith(status: IntentFormStatus.saving));
    try {
      await _repository.declareIntent(
        intent: intent,
        destinationCountry: state.destinationForApi,
        source: source,
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.intentDeclared,
          properties: {
            'intent': intent.wire,
            'destination_country':
                state.destinationForApi ?? kIntentOtherDestination,
            'source': source.wire,
          },
        ),
      );
      if (!isClosed) emit(state.copyWith(status: IntentFormStatus.saved));
    } on Object {
      if (!isClosed) emit(state.copyWith(status: IntentFormStatus.error));
    }
  }
}
