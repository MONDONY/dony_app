import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum TripGroupStatus { initial, loading, loaded, hidden }

class TripGroupState extends Equatable {
  const TripGroupState({
    this.status = TripGroupStatus.initial,
    this.info = TripLegsInfo.none,
  });

  final TripGroupStatus status;
  final TripLegsInfo info;

  @override
  List<Object?> get props => [status, info];
}

/// Étapes du voyage d'une annonce (FLUTTER-4D), pour la fiche d'une étape et
/// la proposition d'annuler les étapes suivantes.
///
/// Tout échec (backend sans l'endpoint, réseau, 404) masque la carte : un
/// trajet isolé et un échec se lisent pareil, il n'y a rien à montrer.
class TripGroupCubit extends Cubit<TripGroupState> {
  TripGroupCubit(this._repository) : super(const TripGroupState());

  final AnnouncementRepository _repository;

  Future<void> load(String announcementId) async {
    emit(TripGroupState(status: TripGroupStatus.loading, info: state.info));
    try {
      final info = await _repository.getTripLegs(announcementId);
      emit(
        TripGroupState(
          status: info.isTrip ? TripGroupStatus.loaded : TripGroupStatus.hidden,
          info: info,
        ),
      );
    } catch (_) {
      emit(const TripGroupState(status: TripGroupStatus.hidden));
    }
  }
}
