import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/receptions/data/models/parcel_role.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ParcelLinkState {
  const ParcelLinkState();
}

class ParcelLinkLoading extends ParcelLinkState {
  const ParcelLinkLoading();
}

class ParcelLinkResolved extends ParcelLinkState {
  const ParcelLinkResolved(this.role);
  final ParcelRole role;
}

class ParcelLinkError extends ParcelLinkState {
  const ParcelLinkError(this.error);
  final AppException error;
}

/// Lien `yadony://colis/{id}` (page publique du QR) : demande au back le rôle
/// de l'utilisateur sur le colis, l'écran choisit ensuite la fiche à ouvrir.
class ParcelLinkCubit extends Cubit<ParcelLinkState> {
  ParcelLinkCubit(this._repository, this._analytics)
    : super(const ParcelLinkLoading());

  final ReceptionRepository _repository;
  final AnalyticsService _analytics;

  Future<void> load(String bidId) async {
    if (state is! ParcelLinkLoading) emit(const ParcelLinkLoading());
    try {
      final role = await _repository.getParcelRole(bidId);
      if (isClosed) return;
      emit(ParcelLinkResolved(role));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.parcelDeepLinkResolved,
          properties: {'role': role.name},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(ParcelLinkError(unwrapDioError(e)));
    }
  }
}
