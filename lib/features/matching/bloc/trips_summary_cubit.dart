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

  /// Nombre de trajets actifs **quand il est connu**, `null` sinon (résumé pas
  /// encore chargé, ou échec réseau).
  ///
  /// Trois cas, pas deux : connu et nul, connu et positif, inconnu. Confondre
  /// « inconnu » avec « zéro » ferait affirmer « Aucun trajet actif » à un
  /// voyageur qui en a cinq, pour toute la session, sur un simple échec réseau.
  /// Les consommateurs doivent traiter `null` comme « je ne sais pas » et
  /// laisser le serveur trancher plutôt que d'inventer un chiffre.
  int? get knownActiveTrips =>
      status == TripsSummaryStatus.loaded ? summary?.activeTrips : null;

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
      // Le bandeau est masqué, mais l'état ne prétend pas pour autant que
      // l'utilisateur n'a aucun trajet : `knownActiveTrips` reste `null`, et
      // c'est ce que lisent les garde-fous qui en dépendent.
      emit(const TripsSummaryState.hidden());
    }
  }
}
