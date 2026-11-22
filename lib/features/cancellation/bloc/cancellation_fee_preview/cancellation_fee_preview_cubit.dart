import 'dart:async' hide TimeoutException;

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_preview_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class CancellationFeePreviewState extends Equatable {
  const CancellationFeePreviewState();

  /// Aperçu à montrer dans le dialogue, `null` quand le dialogue reste celui
  /// d'avant la fonction (aucun frais, aperçu indisponible, lecture en cours).
  CancellationFeePreviewModel? get shownFee => null;

  /// Une lecture est en cours : le bouton de confirmation attend.
  bool get busy => false;

  /// On ne sait pas si des frais s'appliquent (aperçu illisible, ou relecture
  /// ratée sans frais affichés) : un corps qui promet un remboursement
  /// intégral serait peut-être faux.
  bool get feeUnknown => false;

  @override
  List<Object?> get props => const [];
}

/// Lecture de l'aperçu à l'ouverture du dialogue.
class CancellationFeePreviewLoading extends CancellationFeePreviewState {
  const CancellationFeePreviewLoading();

  @override
  bool get busy => true;
}

/// Aperçu illisible : back antérieur à la route (404), 403, réseau, délai,
/// corps inattendu. Aucun bloc des frais, l'annulation reste possible.
class CancellationFeePreviewUnavailable extends CancellationFeePreviewState {
  const CancellationFeePreviewUnavailable();

  @override
  bool get feeUnknown => true;
}

class CancellationFeePreviewLoaded extends CancellationFeePreviewState {
  const CancellationFeePreviewLoaded(
    this.preview, {
    required this.now,
    this.increased = false,
    this.refreshing = false,
    this.recheckFailed = false,
  });

  final CancellationFeePreviewModel preview;

  /// Heure de la lecture, pour dire dans combien de temps part le trajet.
  final DateTime now;

  /// Les frais ont augmenté depuis l'affichage (le palier est passé pendant
  /// que le dialogue était ouvert) : l'expéditeur doit confirmer de nouveau.
  final bool increased;

  /// Relecture avant de confirmer, palier passé ou tout proche.
  final bool refreshing;

  /// La relecture avant de confirmer a échoué : le montant affiché a pu
  /// augmenter. Le dialogue le dit, et l'appui suivant annule.
  final bool recheckFailed;

  @override
  CancellationFeePreviewModel? get shownFee => preview.hasFee ? preview : null;

  @override
  bool get busy => refreshing;

  @override
  bool get feeUnknown => recheckFailed && !preview.hasFee;

  @override
  List<Object?> get props => [
    preview,
    now,
    increased,
    refreshing,
    recheckFailed,
  ];
}

/// Aperçu des frais d'annulation montré à l'expéditeur avant qu'il confirme
/// l'annulation de son colis (yadony-back #779). Lu à chaque ouverture du
/// dialogue, relu à la confirmation dès que le palier
/// [CancellationFeePreviewModel.nextTierAt] est passé ou à moins de
/// [refreshMargin] (l'horloge du téléphone peut retarder sur le serveur).
///
/// Jamais bloquant : toute erreur rend [CancellationFeePreviewUnavailable] ;
/// une relecture ratée demande une seconde confirmation, qui annule.
class CancellationFeePreviewCubit extends Cubit<CancellationFeePreviewState> {
  CancellationFeePreviewCubit(
    this._repository,
    this._analytics, {
    DateTime Function()? clock,
    Duration timeout = defaultTimeout,
  }) : _clock = clock ?? DateTime.now,
       _timeout = timeout,
       super(const CancellationFeePreviewLoading());

  /// Au-delà, l'aperçu est abandonné : le bouton de confirmation ne doit pas
  /// attendre le délai réseau complet (30 s et ses relances).
  static const defaultTimeout = Duration(seconds: 6);

  /// Relecture avant de confirmer dès `nextTierAt − refreshMargin` : un
  /// téléphone en retard sur le serveur confirmerait sinon l'ancien montant
  /// alors que le serveur applique déjà le palier suivant.
  static const refreshMargin = Duration(minutes: 2);

  final CancellationRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _clock;
  final Duration _timeout;
  String? _bidId;

  Future<void> load(String bidId) async {
    _bidId = bidId;
    if (state is! CancellationFeePreviewLoading) {
      emit(const CancellationFeePreviewLoading());
    }
    final preview = await _fetch(bidId, stage: 'load');
    if (isClosed) return;
    emit(
      preview == null
          ? const CancellationFeePreviewUnavailable()
          : CancellationFeePreviewLoaded(preview, now: _clock()),
    );
  }

  /// Vrai quand l'annulation peut partir maintenant. Faux pendant une
  /// lecture, quand les frais viennent d'augmenter (le dialogue montre le
  /// nouveau montant) ou quand la relecture a échoué (le dialogue prévient
  /// que le montant a pu augmenter) : la confirmation suivante annule.
  Future<bool> confirm() async {
    final current = state;
    switch (current) {
      case CancellationFeePreviewLoading():
        return false;
      case CancellationFeePreviewUnavailable():
        return true;
      case CancellationFeePreviewLoaded():
        if (current.refreshing) return false;
        if (current.recheckFailed) return true;
        final next = current.preview.nextTierAt;
        final id = _bidId;
        if (next == null ||
            id == null ||
            _clock().isBefore(next.subtract(refreshMargin))) {
          return true;
        }
        emit(
          CancellationFeePreviewLoaded(
            current.preview,
            now: current.now,
            increased: current.increased,
            refreshing: true,
          ),
        );
        final fresh = await _fetch(id, stage: 'refresh');
        if (isClosed) return false;
        if (fresh == null) {
          // Relecture ratée : le montant affiché a pu augmenter. On prévient
          // une fois, la confirmation suivante annule (jamais bloquant).
          emit(
            CancellationFeePreviewLoaded(
              current.preview,
              now: current.now,
              increased: current.increased,
              recheckFailed: true,
            ),
          );
          return false;
        }
        final increased = fresh.fee > current.preview.fee;
        emit(
          CancellationFeePreviewLoaded(
            fresh,
            now: _clock(),
            increased: increased,
          ),
        );
        return !increased;
    }
  }

  Future<CancellationFeePreviewModel?> _fetch(
    String bidId, {
    required String stage,
  }) async {
    try {
      return await _repository
          .getFeePreview(bidId)
          .timeout(_timeout, onTimeout: () => throw const TimeoutException());
    } catch (e) {
      _trackFailure(e, stage);
      return null;
    }
  }

  /// Un back antérieur à la route répond 404 : cas attendu tant que la
  /// fonction n'est pas déployée, jamais signalé.
  void _trackFailure(Object e, String stage) {
    final malformed = e is FormatException || e is TypeError;
    final error = malformed ? null : unwrapDioError(e);
    if (error is NotFoundException) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.cancellationFeePreviewFailed,
        properties: {
          'error_code': malformed
              ? 'invalid_payload'
              : error?.code ?? 'unknown',
          'stage': stage,
        },
      ),
    );
  }
}
