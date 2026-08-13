import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/data/repositories/dispute_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DisputeListBloc extends Bloc<DisputeListEvent, DisputeListState> {
  final DisputeRepository _repository;
  final AnalyticsService _analytics;
  bool _openedLogged = false;

  DisputeListBloc(this._repository, this._analytics)
    : super(const DisputeListInitial()) {
    on<DisputesLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(
    DisputesLoadRequested event,
    Emitter<DisputeListState> emit,
  ) async {
    emit(const DisputeListLoading());
    try {
      final disputes = await _repository.getMyDisputes();
      if (!_openedLogged) {
        _openedLogged = true;
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.disputesOpened,
            properties: {'count': disputes.length},
          ),
        );
      }
      emit(DisputeListLoaded(disputes));
    } catch (e) {
      emit(DisputeListError(unwrapDioError(e)));
    }
  }
}
