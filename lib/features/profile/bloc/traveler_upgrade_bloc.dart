import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/bloc/traveler_upgrade_event.dart';
import 'package:dony/features/profile/bloc/traveler_upgrade_state.dart';
import 'package:dony/features/profile/data/traveler_upgrade_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TravelerUpgradeBloc
    extends Bloc<TravelerUpgradeEvent, TravelerUpgradeState> {
  final TravelerUpgradeRepository _repository;

  TravelerUpgradeBloc(this._repository) : super(const TravelerUpgradeInitial()) {
    on<TravelerUpgradeActivateRequested>(_onActivate);
  }

  Future<void> _onActivate(
    TravelerUpgradeActivateRequested event,
    Emitter<TravelerUpgradeState> emit,
  ) async {
    emit(const TravelerUpgradeLoading());
    try {
      final user = await _repository.activateTravelerRole();
      emit(TravelerUpgradeSuccess(user));
    } catch (e) {
      emit(TravelerUpgradeError(unwrapDioError(e)));
    }
  }
}
