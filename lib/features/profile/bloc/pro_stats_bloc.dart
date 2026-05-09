import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/data/models/pro_stats_model.dart';
import 'package:dony/features/profile/data/pro_stats_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'pro_stats_event.dart';
part 'pro_stats_state.dart';

class ProStatsBloc extends Bloc<ProStatsEvent, ProStatsState> {
  final ProStatsRepository _repository;

  ProStatsBloc(this._repository) : super(ProStatsInitial()) {
    on<ProStatsLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(
    ProStatsLoadRequested event,
    Emitter<ProStatsState> emit,
  ) async {
    emit(ProStatsLoading());
    try {
      final stats = await _repository.fetchStats();
      emit(ProStatsLoaded(stats));
    } on AppException catch (e) {
      emit(ProStatsError(e.message));
    } catch (_) {
      emit(ProStatsError('Impossible de charger les statistiques.'));
    }
  }
}
