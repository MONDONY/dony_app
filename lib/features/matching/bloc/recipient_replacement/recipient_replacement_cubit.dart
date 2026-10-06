import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/server_date_time.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class RecipientReplacementState {
  const RecipientReplacementState();
}

class RecipientReplacementIdle extends RecipientReplacementState {
  const RecipientReplacementIdle();
}

class RecipientReplacementSubmitting extends RecipientReplacementState {
  const RecipientReplacementSubmitting();
}

/// Demande envoyée : [bid] est le colis à jour renvoyé par le serveur
/// (`recipientReplacementRequestedAt` renseigné).
class RecipientReplacementSent extends RecipientReplacementState {
  const RecipientReplacementSent(this.bid);

  final BidModel bid;
}

/// 429 `recipient-replacement-too-soon` : une demande a déjà été faite il y a
/// moins de 12 h. [nextRequestAllowedAt] vient du ProblemDetail (`null` s'il
/// manque ou est illisible).
class RecipientReplacementTooSoon extends RecipientReplacementState {
  const RecipientReplacementTooSoon(this.nextRequestAllowedAt);

  final DateTime? nextRequestAllowedAt;
}

/// 409 : le destinataire n'est plus en refus (`recipient-not-declined`,
/// l'expéditeur en a déjà désigné un autre) ou le colis n'est plus en cours
/// (`recipient-replacement-not-allowed`). Le détail est à recharger.
class RecipientReplacementConflict extends RecipientReplacementState {
  const RecipientReplacementConflict(this.code);

  final String? code;
}

class RecipientReplacementFailure extends RecipientReplacementState {
  const RecipientReplacementFailure(this.error);

  final AppException error;
}

/// Le voyageur demande à l'expéditeur de désigner un autre destinataire après
/// un refus (`POST /bids/{bidId}/recipient/replacement-request`, yadony-back
/// #412).
class RecipientReplacementCubit extends Cubit<RecipientReplacementState> {
  RecipientReplacementCubit(this._repository, this._analytics)
    : super(const RecipientReplacementIdle());

  final BidRepository _repository;
  final AnalyticsService _analytics;

  static const tooSoonCode = 'recipient-replacement-too-soon';

  Future<void> request(BidModel bid) async {
    if (state is RecipientReplacementSubmitting) return;
    emit(const RecipientReplacementSubmitting());
    try {
      final updated = await _repository.requestRecipientReplacement(bid.id);
      if (isClosed) return;
      emit(RecipientReplacementSent(updated));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.recipientReplacementRequested,
          properties: {'status': bid.status, 'outcome': 'sent'},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      if (error is RateLimitException || _statusOf(e) == 429) {
        emit(RecipientReplacementTooSoon(_nextAllowedAt(e)));
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.recipientReplacementRequested,
            properties: {'status': bid.status, 'outcome': 'too_soon'},
          ),
        );
        return;
      }
      if (error is ConflictException) {
        emit(RecipientReplacementConflict(error.code));
        return;
      }
      emit(RecipientReplacementFailure(error));
    }
  }

  static int? _statusOf(Object e) =>
      e is DioException ? e.response?.statusCode : null;

  /// `nextRequestAllowedAt` du ProblemDetail 429 (propriété de premier niveau).
  static DateTime? _nextAllowedAt(Object e) {
    if (e is! DioException) return null;
    final data = e.response?.data;
    if (data is! Map) return null;
    final raw = data['nextRequestAllowedAt'];
    if (raw is! String || raw.trim().isEmpty) return null;
    try {
      return parseServerDateTime(raw);
    } on FormatException {
      return null;
    }
  }
}
