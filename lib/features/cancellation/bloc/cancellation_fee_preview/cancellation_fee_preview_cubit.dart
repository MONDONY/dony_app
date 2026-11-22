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
/// corps inattendu. Le dialogue reste celui d'avant la fonction et
/// l'annulation reste possible.
class CancellationFeePreviewUnavailable extends CancellationFeePreviewState {
  const CancellationFeePreviewUnavailable();
}

class CancellationFeePreviewLoaded extends CancellationFeePreviewState {
  const CancellationFeePreviewLoaded(
    this.preview, {
    required this.now,
    this.increased = false,
    this.refreshing = false,
  });

  final CancellationFeePreviewModel preview;

  /// Heure de la lecture, pour dire dans combien de temps part le trajet.
  final DateTime now;

  /// Les frais ont augmenté depuis l'affichage (le palier est passé pendant
  /// que le dialogue était ouvert) : l'expéditeur doit confirmer de nouveau.
  final bool increased;

  /// Relecture avant de confirmer, palier passé.
  final bool refreshing;

  @override
  CancellationFeePreviewModel? get shownFee => preview.hasFee ? preview : null;

  @override
  bool get busy => refreshing;

  @override
  List<Object?> get props => [preview, now, increased, refreshing];
}

/// Aperçu des frais d'annulation montré à l'expéditeur avant qu'il confirme
/// l'annulation de son colis (yadony-back #779). Lu à chaque ouverture du
/// dialogue, relu à la confirmation si le palier [CancellationFeePreviewModel.nextTierAt]
/// est passé entre-temps.
///
/// Jamais bloquant : toute erreur rend [CancellationFeePreviewUnavailable], et
/// une relecture ratée laisse confirmer.
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
  /// lecture, ou quand les frais viennent d'augmenter : le dialogue montre
  /// alors le nouveau montant et attend une seconde confirmation.
  Future<bool> confirm() async {
    final current = state;
    switch (current) {
      case CancellationFeePreviewLoading():
        return false;
      case CancellationFeePreviewUnavailable():
        return true;
      case CancellationFeePreviewLoaded():
        if (current.refreshing) return false;
        final next = current.preview.nextTierAt;
        final id = _bidId;
        if (next == null || id == null || !_clock().isAfter(next)) return true;
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
          // Relecture ratée : on ne bloque pas. L'expéditeur a vu les frais
          // et la mention « Annuler plus tard coûte plus cher ».
          emit(
            CancellationFeePreviewLoaded(
              current.preview,
              now: current.now,
              increased: current.increased,
            ),
          );
          return true;
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
