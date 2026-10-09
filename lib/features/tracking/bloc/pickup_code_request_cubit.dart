import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/server_date_time.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class PickupCodeRequestState {
  const PickupCodeRequestState();
}

class PickupCodeRequestIdle extends PickupCodeRequestState {
  const PickupCodeRequestIdle();
}

class PickupCodeRequestSending extends PickupCodeRequestState {
  const PickupCodeRequestSending();
}

/// Demande transmise : l'expéditeur est prévenu.
class PickupCodeRequestSent extends PickupCodeRequestState {
  const PickupCodeRequestSent({this.nextRequestAllowedAt});

  final DateTime? nextRequestAllowedAt;
}

/// 429 `code-request-too-soon` : une demande a déjà été faite il y a moins de
/// 15 min. [nextRequestAllowedAt] vient du ProblemDetail (`null` s'il manque
/// ou est illisible).
class PickupCodeRequestTooSoon extends PickupCodeRequestState {
  const PickupCodeRequestTooSoon(this.nextRequestAllowedAt);

  final DateTime? nextRequestAllowedAt;

  /// Minutes restantes, arrondies à la minute supérieure, au moins 1.
  /// `null` si le serveur n'a pas donné l'échéance.
  int? minutesLeft(DateTime now) {
    final next = nextRequestAllowedAt;
    if (next == null) return null;
    final seconds = next.difference(now).inSeconds;
    if (seconds <= 0) return 1;
    return (seconds + 59) ~/ 60;
  }
}

class PickupCodeRequestFailure extends PickupCodeRequestState {
  const PickupCodeRequestFailure(this.error);

  final AppException error;
}

/// Le voyageur demande à l'expéditeur un nouveau code de retrait, bloqué ou
/// expiré (`POST /tracking/{bidId}/request-code`, yadony-back #461,
/// FLUTTER-G2). L'expéditeur reçoit une notification qui ouvre la
/// régénération du code.
class PickupCodeRequestCubit extends Cubit<PickupCodeRequestState> {
  PickupCodeRequestCubit(this._repository, this._analytics)
    : super(const PickupCodeRequestIdle());

  final TrackingRepository _repository;
  final AnalyticsService _analytics;

  static const tooSoonCode = 'code-request-too-soon';

  Future<void> request(String bidId, {required String source}) async {
    if (state is PickupCodeRequestSending) return;
    emit(const PickupCodeRequestSending());
    try {
      final result = await _repository.requestNewCode(bidId);
      if (isClosed) return;
      emit(
        PickupCodeRequestSent(
          nextRequestAllowedAt: result.nextRequestAllowedAt,
        ),
      );
      _log(source, 'sent');
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      if (error is RateLimitException ||
          error.code == tooSoonCode ||
          _statusOf(e) == 429) {
        emit(PickupCodeRequestTooSoon(_nextAllowedAt(e)));
        _log(source, 'too_soon');
        return;
      }
      emit(PickupCodeRequestFailure(error));
      _log(source, 'error');
    }
  }

  void _log(String source, String outcome) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.pickupCodeRequested,
        properties: {'source': source, 'outcome': outcome},
      ),
    );
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
