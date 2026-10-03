import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Geste en cours ou abouti sur un colis chargé.
enum ReceptionAction {
  idle,
  confirming,
  declining,
  confirmed,
  declined,

  /// Destinataire confirmé retiré du colis (FLUTTER-9F) : l'écran se ferme.
  withdrawn,
  failed,
}

sealed class ReceptionDetailState {
  const ReceptionDetailState();
}

class ReceptionDetailLoading extends ReceptionDetailState {
  const ReceptionDetailLoading();
}

class ReceptionDetailLoaded extends ReceptionDetailState {
  const ReceptionDetailLoaded(
    this.reception, {
    this.action = ReceptionAction.idle,
    this.actionError,
  });

  final Reception reception;
  final ReceptionAction action;

  /// Erreur du dernier geste, avec [ReceptionAction.failed].
  final AppException? actionError;

  bool get busy =>
      action == ReceptionAction.confirming ||
      action == ReceptionAction.declining;
}

/// Chargement impossible. Une [NotFoundException] veut dire que le colis
/// n'est plus disponible (lien refusé, colis retiré) : rien à réessayer.
class ReceptionDetailError extends ReceptionDetailState {
  const ReceptionDetailError(this.error);

  final AppException error;

  bool get notFound => error is NotFoundException;
}

/// Écran « Colis à recevoir » : le destinataire confirme que le colis est
/// pour lui (ou le refuse), puis suit ses étapes et lit son code de retrait.
class ReceptionDetailCubit extends Cubit<ReceptionDetailState> {
  ReceptionDetailCubit(this._repository, this._analytics)
    : super(const ReceptionDetailLoading());

  final ReceptionRepository _repository;
  final AnalyticsService _analytics;

  String? _bidId;

  /// Ouverture mesurée une fois, pas à chaque « Réessayer ».
  bool _openTracked = false;

  Future<void> load(String bidId) async {
    _bidId = bidId;
    emit(const ReceptionDetailLoading());
    try {
      final reception = await _repository.getReception(bidId);
      if (isClosed) return;
      emit(ReceptionDetailLoaded(reception));
      if (!_openTracked) {
        _openTracked = true;
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.receptionOpened,
            properties: {
              'link_status': reception.linkStatus,
              'bid_status': reception.bidStatus,
            },
          ),
        );
      }
    } catch (e) {
      if (isClosed) return;
      emit(ReceptionDetailError(unwrapDioError(e)));
    }
  }

  Future<void> retry() async {
    final id = _bidId;
    if (id != null) await load(id);
  }

  /// « Oui, c'est pour moi ».
  Future<void> confirm() async {
    final current = state;
    if (current is! ReceptionDetailLoaded || current.busy) return;
    final reception = current.reception;
    emit(ReceptionDetailLoaded(reception, action: ReceptionAction.confirming));
    try {
      final updated = await _repository.confirm(reception.bidId);
      if (isClosed) return;
      emit(ReceptionDetailLoaded(updated, action: ReceptionAction.confirmed));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.receptionConfirmed,
          properties: {'bid_status': updated.bidStatus},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      _fail(reception, unwrapDioError(e));
    }
  }

  /// « Ce n'est pas pour moi » (lien en attente) ou « Me retirer de ce
  /// colis » (lien confirmé, FLUTTER-9F), après la confirmation de l'écran.
  /// Même route côté back, qui distingue les deux cas.
  Future<void> decline() async {
    final current = state;
    if (current is! ReceptionDetailLoaded || current.busy) return;
    final reception = current.reception;
    final withdraw = reception.isConfirmed;
    emit(ReceptionDetailLoaded(reception, action: ReceptionAction.declining));
    try {
      await _repository.decline(reception.bidId);
      if (isClosed) return;
      emit(
        ReceptionDetailLoaded(
          reception,
          action: withdraw
              ? ReceptionAction.withdrawn
              : ReceptionAction.declined,
        ),
      );
      unawaited(
        _analytics.logEvent(
          withdraw
              ? AnalyticsEvents.receptionWithdrawn
              : AnalyticsEvents.receptionDeclined,
          properties: {'bid_status': reception.bidStatus},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      if (error is ConflictException) {
        // Déjà confirmé ailleurs (autre appareil) : on montre l'état réel.
        await _reloadAfterConflict(reception, error);
        return;
      }
      _fail(reception, error);
    }
  }

  void _fail(Reception reception, AppException error) {
    if (error is NotFoundException) {
      emit(ReceptionDetailError(error));
      return;
    }
    emit(
      ReceptionDetailLoaded(
        reception,
        action: ReceptionAction.failed,
        actionError: error,
      ),
    );
  }

  Future<void> _reloadAfterConflict(
    Reception reception,
    AppException error,
  ) async {
    try {
      final fresh = await _repository.getReception(reception.bidId);
      if (isClosed) return;
      emit(
        ReceptionDetailLoaded(
          fresh,
          action: ReceptionAction.failed,
          actionError: error,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      _fail(reception, error);
    }
  }
}
