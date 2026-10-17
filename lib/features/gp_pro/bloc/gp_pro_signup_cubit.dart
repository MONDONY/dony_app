import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GpProSignupState extends Equatable {
  const GpProSignupState({
    this.checked = false,
    this.frequency,
    this.commercialName = '',
    this.submitting = false,
  });

  final bool checked;
  final GpProFrequency? frequency;
  final String commercialName;
  final bool submitting;

  /// Case décochée, ou cochée avec la fréquence (obligatoire) choisie.
  bool get isComplete => !checked || frequency != null;

  GpProSignupState copyWith({
    bool? checked,
    GpProFrequency? frequency,
    String? commercialName,
    bool? submitting,
  }) => GpProSignupState(
    checked: checked ?? this.checked,
    frequency: frequency ?? this.frequency,
    commercialName: commercialName ?? this.commercialName,
    submitting: submitting ?? this.submitting,
  );

  @override
  List<Object?> get props => [checked, frequency, commercialName, submitting];
}

/// Case « Je suis GP » de l'étape d'intention de l'inscription. L'envoi ne
/// bloque jamais l'inscription : toute erreur est avalée.
class GpProSignupCubit extends Cubit<GpProSignupState> {
  GpProSignupCubit(this._repository, this._analytics)
    : super(const GpProSignupState());

  final GpProRepository _repository;
  final AnalyticsService _analytics;

  void toggle(bool checked) => emit(state.copyWith(checked: checked));

  void selectFrequency(GpProFrequency frequency) =>
      emit(state.copyWith(frequency: frequency));

  void setCommercialName(String name) =>
      emit(state.copyWith(commercialName: name));

  /// Envoie la demande si la case est cochée, la fréquence choisie et
  /// l'intention compatible (voyageur ou les deux). Ne lève jamais.
  Future<void> submitIfChecked(UserIntent? intent) async {
    final frequency = state.frequency;
    if (!state.checked ||
        frequency == null ||
        intent == null ||
        intent == UserIntent.sender ||
        state.submitting) {
      return;
    }
    emit(state.copyWith(submitting: true));
    final name = state.commercialName.trim();
    final commercialName = name.isEmpty ? null : name;
    try {
      await _repository.apply(
        frequency: frequency,
        commercialName: commercialName,
        source: GpProSource.signup,
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.gpProApplicationSubmitted,
          properties: {
            'source': GpProSource.signup.name,
            'frequency': frequency.wire,
            'document_count': 0,
            'has_commercial_name': commercialName != null,
          },
        ),
      );
    } catch (e) {
      AppLog.warn('gp_pro_signup_apply_failed');
    }
    if (!isClosed) emit(state.copyWith(submitting: false));
  }
}
