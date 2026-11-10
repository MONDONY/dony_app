import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class TravelerStatusState extends Equatable {
  const TravelerStatusState();

  @override
  List<Object?> get props => [];
}

/// Rien n'est choisi : aucune présélection.
class TravelerStatusInitial extends TravelerStatusState {
  const TravelerStatusInitial();
}

/// « Particulier » est en cours d'envoi.
class TravelerStatusSubmitting extends TravelerStatusState {
  const TravelerStatusSubmitting();
}

class TravelerStatusSuccess extends TravelerStatusState {
  const TravelerStatusSuccess(this.declaration);

  final TravelerStatusDeclaration declaration;

  @override
  List<Object?> get props => [declaration.status, declaration.declaredAt];
}

/// Le back a refusé ou le réseau a coupé : le voyageur peut réessayer.
class TravelerStatusFailure extends TravelerStatusState {
  const TravelerStatusFailure(this.error);

  final AppException error;

  /// Code métier du back (`traveler-status-invalid`…), `unknown` sinon.
  String get code => error.code ?? 'unknown';

  @override
  List<Object?> get props => [error];
}

/// Déclaration « particulier » du voyageur (`PUT /traveler-status/me`).
///
/// « GP Pro » n'est pas une déclaration : c'est une demande validée par
/// l'équipe, portée par le formulaire GP Pro.
class TravelerStatusCubit extends Cubit<TravelerStatusState> {
  TravelerStatusCubit(this._repository, this._analytics)
    : super(const TravelerStatusInitial());

  final TravelerStatusRepository _repository;
  final AnalyticsService _analytics;

  /// Le voyageur choisit « Particulier » : la confirmation de voyager à titre
  /// personnel est le texte sous l'option, envoyée avec la déclaration.
  Future<void> chooseIndividual() async {
    if (state is TravelerStatusSubmitting || state is TravelerStatusSuccess) {
      return;
    }
    emit(const TravelerStatusSubmitting());
    const status = TravelerStatus.individual;
    try {
      final declaration = await _repository.declareIndividual();
      if (isClosed) return;
      emit(TravelerStatusSuccess(declaration));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.travelerStatusDeclared,
          properties: {'status': status.wire},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      emit(TravelerStatusFailure(error));
      // Jamais la saisie : seulement le statut visé et le code d'erreur.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.travelerStatusDeclareFailed,
          properties: {
            'status': status.wire,
            'error_code': error.code ?? 'unknown',
          },
        ),
      );
    }
  }
}
