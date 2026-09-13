import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum RevenueDetailsStatus { initial, loading, loaded, error }

class RevenueDetailsState extends Equatable {
  final RevenueDetailsStatus status;
  final RevenueDetailsModel? details;

  const RevenueDetailsState({
    this.status = RevenueDetailsStatus.initial,
    this.details,
  });

  @override
  List<Object?> get props => [status, details];
}

/// Alimente la feuille « Revenus » du hub. Un cubit par ouverture de feuille
/// (fabrique GetIt) : la période vient du tap, rien n'est partagé.
class RevenueDetailsCubit extends Cubit<RevenueDetailsState> {
  RevenueDetailsCubit(this._repository) : super(const RevenueDetailsState());

  final AnnouncementRepository _repository;

  Future<void> load(StatsPeriod period) async {
    emit(const RevenueDetailsState(status: RevenueDetailsStatus.loading));
    try {
      final details = await _repository.getRevenueDetails(
        period: period.apiValue,
      );
      // La feuille peut être retirée (glissée vers le bas) pendant la requête :
      // le cubit est alors fermé et un emit lèverait un StateError vers Sentry.
      if (isClosed) return;
      emit(
        RevenueDetailsState(
          status: RevenueDetailsStatus.loaded,
          details: details,
        ),
      );
    } catch (_) {
      // Ancien backend (404) ou réseau : la feuille montre son état d'erreur
      // avec « Réessayer », rien ne remonte à Sentry.
      if (isClosed) return;
      emit(const RevenueDetailsState(status: RevenueDetailsStatus.error));
    }
  }
}
