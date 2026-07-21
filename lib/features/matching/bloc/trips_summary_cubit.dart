import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum TripsSummaryStatus { initial, loading, loaded, hidden }

class TripsSummaryState extends Equatable {
  final TripsSummaryStatus status;
  final TripsSummaryModel? summary;

  const TripsSummaryState._(this.status, [this.summary]);

  const TripsSummaryState.initial() : this._(TripsSummaryStatus.initial);
  const TripsSummaryState.loading() : this._(TripsSummaryStatus.loading);
  const TripsSummaryState.loaded(TripsSummaryModel summary)
    : this._(TripsSummaryStatus.loaded, summary);

  /// Erreur réseau/serveur : le bandeau est simplement masqué (spec).
  const TripsSummaryState.hidden() : this._(TripsSummaryStatus.hidden);

  @override
  List<Object?> get props => [
    status,
    summary?.activeTrips,
    summary?.kgSold,
    summary?.revenue,
    summary?.tripsPublished,
    summary?.parcelsSent,
  ];
}

class TripsSummaryCubit extends Cubit<TripsSummaryState> {
  TripsSummaryCubit(this._repository)
    : super(const TripsSummaryState.initial());

  final AnnouncementRepository _repository;

  /// Le défaut vient de [StatsPeriod] : une seule déclaration pour toute
  /// l'app, alignée sur celle du backend.
  Future<void> load({StatsPeriod period = StatsPeriod.thirtyDays}) async {
    emit(const TripsSummaryState.loading());
    try {
      final summary = await _repository.getTripsSummary(
        period: period.apiValue,
      );
      emit(TripsSummaryState.loaded(summary));
    } catch (_) {
      emit(const TripsSummaryState.hidden());
    }
  }
}
