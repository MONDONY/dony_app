import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/data/activation_repository.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ActivationState extends Equatable {
  const ActivationState();

  @override
  List<Object?> get props => [];
}

class ActivationInitial extends ActivationState {
  const ActivationInitial();
}

class ActivationLoading extends ActivationState {
  const ActivationLoading();
}

class ActivationLoaded extends ActivationState {
  const ActivationLoaded(this.status);

  final ActivationStatus status;

  @override
  List<Object?> get props => [status];
}

/// Backend sans l'endpoint (prod pas encore déployée) : parcours historique.
class ActivationUnavailable extends ActivationState {
  const ActivationUnavailable();
}

class ActivationError extends ActivationState {
  const ActivationError();
}

/// Statut d'activation partagé par l'accueil, les premiers pas et le KYC.
class ActivationCubit extends Cubit<ActivationState> {
  ActivationCubit(this._repository, this._analytics)
    : super(const ActivationInitial());

  final ActivationRepository _repository;
  final AnalyticsService _analytics;

  /// Ne repasse pas par `ActivationLoading` quand un statut est déjà connu :
  /// le rafraîchissement ne fait pas clignoter la carte d'accueil.
  Future<void> load() async {
    if (state is! ActivationLoaded) emit(const ActivationLoading());
    try {
      final status = await _repository.fetch();
      if (isClosed) return;
      emit(
        status == null
            ? const ActivationUnavailable()
            : ActivationLoaded(status),
      );
    } on Object {
      if (isClosed) return;
      if (state is ActivationLoaded) return;
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.blocError,
          properties: {'bloc': 'ActivationCubit'},
        ),
      );
      emit(const ActivationError());
    }
  }

  void reset() => emit(const ActivationInitial());
}
