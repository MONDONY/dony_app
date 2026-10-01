import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ReceptionsState {
  const ReceptionsState();
}

class ReceptionsLoading extends ReceptionsState {
  const ReceptionsLoading();
}

class ReceptionsLoaded extends ReceptionsState {
  const ReceptionsLoaded(this.receptions);

  final List<Reception> receptions;
}

class ReceptionsError extends ReceptionsState {
  const ReceptionsError(this.error);

  final AppException error;
}

/// « Colis à recevoir » de l'onglet Suivi.
///
/// La section est secondaire : un échec ne s'affiche jamais. Un back antérieur
/// au lot 2 répond 404 sur `/receptions`, la section reste alors masquée. Un
/// rafraîchissement raté garde la liste déjà affichée.
class ReceptionsCubit extends Cubit<ReceptionsState> {
  ReceptionsCubit(this._repository, this._analytics)
    : super(const ReceptionsLoading());

  final ReceptionRepository _repository;
  final AnalyticsService _analytics;

  /// La section n'est mesurée qu'une fois par ouverture de l'onglet.
  bool _viewTracked = false;

  /// Premier chargement comme rafraîchissement silencieux (retour sur
  /// l'onglet, retour du détail).
  Future<void> load() async {
    if (state is! ReceptionsLoaded) emit(const ReceptionsLoading());
    try {
      final receptions = await _repository.getReceptions();
      if (isClosed) return;
      emit(ReceptionsLoaded(receptions));
      if (receptions.isNotEmpty && !_viewTracked) {
        _viewTracked = true;
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.receptionsSectionViewed,
            properties: {
              'count': receptions.length,
              'pending': receptions.where((r) => r.isPending).length,
            },
          ),
        );
      }
    } catch (e) {
      if (isClosed || state is ReceptionsLoaded) return;
      emit(ReceptionsError(unwrapDioError(e)));
    }
  }
}
