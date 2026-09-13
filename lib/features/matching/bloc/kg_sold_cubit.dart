import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/kg_sold_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum KgSoldStatus { initial, loading, loaded, error }

class KgSoldState extends Equatable {
  final KgSoldStatus status;
  final KgSoldModel? details;

  const KgSoldState({this.status = KgSoldStatus.initial, this.details});

  @override
  List<Object?> get props => [status, details];
}

/// Alimente la feuille « Kg vendus » du hub. Un cubit par ouverture de feuille
/// (fabrique GetIt) : la période vient du tap, rien n'est partagé.
class KgSoldCubit extends Cubit<KgSoldState> {
  KgSoldCubit(this._repository) : super(const KgSoldState());

  final AnnouncementRepository _repository;

  Future<void> load(StatsPeriod period) async {
    emit(const KgSoldState(status: KgSoldStatus.loading));
    try {
      final details = await _repository.getKgSold(period: period.apiValue);
      // La feuille peut être retirée (glissée vers le bas) pendant la requête :
      // le cubit est alors fermé et un emit lèverait un StateError vers Sentry.
      if (isClosed) return;
      emit(KgSoldState(status: KgSoldStatus.loaded, details: details));
    } catch (_) {
      // Ancien backend (404) ou réseau : la feuille montre son état d'erreur
      // avec « Réessayer », rien ne remonte à Sentry.
      if (isClosed) return;
      emit(const KgSoldState(status: KgSoldStatus.error));
    }
  }
}
