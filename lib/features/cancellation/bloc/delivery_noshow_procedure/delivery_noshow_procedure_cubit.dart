import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/data/models/delivery_noshow_procedure_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class DeliveryNoShowProcedureState {
  const DeliveryNoShowProcedureState();
}

class DeliveryNoShowProcedureLoading extends DeliveryNoShowProcedureState {
  const DeliveryNoShowProcedureLoading();
}

/// Back antérieur à la procédure (404) : l'écran garde l'ancien parcours.
class DeliveryNoShowProcedureUnavailable extends DeliveryNoShowProcedureState {
  const DeliveryNoShowProcedureUnavailable();
}

class DeliveryNoShowProcedureLoaded extends DeliveryNoShowProcedureState {
  const DeliveryNoShowProcedureLoaded(
    this.procedure, {
    required this.now,
    this.submitting = false,
    this.submitError,
    this.appointmentSaved = false,
  });

  final DeliveryNoShowProcedureModel procedure;

  /// Heure de référence du compteur d'attente (rafraîchie chaque minute).
  final DateTime now;
  final bool submitting;
  final AppException? submitError;

  /// Un nouveau rendez-vous vient d'être enregistré (feuille à fermer).
  final bool appointmentSaved;

  /// Minutes restantes avant de pouvoir signaler, 0 si c'est déjà possible.
  int get remainingWaitMinutes {
    final at = procedure.reportAvailableAt;
    if (at == null || procedure.waitElapsed || !at.isAfter(now)) return 0;
    return (at.difference(now).inSeconds / 60).ceil();
  }
}

class DeliveryNoShowProcedureError extends DeliveryNoShowProcedureState {
  const DeliveryNoShowProcedureError(this.error);
  final AppException error;
}

/// Procédure « destinataire absent » d'un colis (FLUTTER-E2) : compteur
/// d'attente et preuve de contact avant le signalement (voyageur), garde du
/// colis, nouveau rendez-vous (expéditeur) et colis « non réclamé ».
class DeliveryNoShowProcedureCubit extends Cubit<DeliveryNoShowProcedureState> {
  DeliveryNoShowProcedureCubit(
    this._repository,
    this._analytics, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const DeliveryNoShowProcedureLoading());

  final CancellationRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _clock;
  Timer? _ticker;
  String? _bidId;

  Future<void> load(String bidId) async {
    _bidId = bidId;
    try {
      final procedure = await _repository.getDeliveryNoShowProcedure(bidId);
      if (isClosed) return;
      emit(DeliveryNoShowProcedureLoaded(procedure, now: _clock()));
      _scheduleTicker(procedure);
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      emit(
        error is NotFoundException
            ? const DeliveryNoShowProcedureUnavailable()
            : DeliveryNoShowProcedureError(error),
      );
    }
  }

  Future<void> refresh() async {
    final id = _bidId;
    if (id != null) await load(id);
  }

  /// Compteur : un tick par minute tant que l'attente court ; à son terme, la
  /// procédure est relue (le serveur reste l'autorité sur `canReport`).
  void _scheduleTicker(DeliveryNoShowProcedureModel procedure) {
    _ticker?.cancel();
    final at = procedure.reportAvailableAt;
    if (procedure.reported || procedure.waitElapsed || at == null) return;
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! DeliveryNoShowProcedureLoaded) return;
    final now = _clock();
    final at = current.procedure.reportAvailableAt;
    if (at != null && !now.isBefore(at)) {
      _ticker?.cancel();
      unawaited(refresh());
      return;
    }
    emit(DeliveryNoShowProcedureLoaded(current.procedure, now: now));
  }

  Future<void> setRetryAppointment({
    required DateTime appointmentAt,
    String? note,
  }) async {
    final current = state;
    if (current is! DeliveryNoShowProcedureLoaded || current.submitting) {
      return;
    }
    emit(
      DeliveryNoShowProcedureLoaded(
        current.procedure,
        now: current.now,
        submitting: true,
      ),
    );
    try {
      final updated = await _repository.setRetryAppointment(
        current.procedure.bidId,
        appointmentAt: appointmentAt,
        note: note,
      );
      if (isClosed) return;
      emit(
        DeliveryNoShowProcedureLoaded(
          updated,
          now: _clock(),
          appointmentSaved: true,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.deliveryRetryAppointmentSet,
          properties: {
            'hours_before_hold_end':
                updated.holdUntil?.difference(appointmentAt).inHours ?? -1,
          },
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        DeliveryNoShowProcedureLoaded(
          current.procedure,
          now: current.now,
          submitError: unwrapDioError(e),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
