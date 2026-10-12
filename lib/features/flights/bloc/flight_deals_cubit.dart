import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FlightDealsStatus { initial, loading, loaded, hidden }

class FlightDealsState extends Equatable {
  const FlightDealsState({
    this.status = FlightDealsStatus.initial,
    this.deals = const [],
    this.personalized = false,
  });

  final FlightDealsStatus status;
  final List<FlightDeal> deals;
  final bool personalized;

  @override
  List<Object?> get props => [status, deals, personalized];
}

/// Carrousel « Bons plans pour vous ». Un échec masque la section plutôt que
/// d'afficher une erreur : la recherche reste l'action principale de l'onglet.
class FlightDealsCubit extends Cubit<FlightDealsState> {
  FlightDealsCubit(this._repository) : super(const FlightDealsState());

  final FlightsRepository _repository;

  Future<void> load() async {
    if (state.status != FlightDealsStatus.loaded) {
      emit(const FlightDealsState(status: FlightDealsStatus.loading));
    }
    try {
      final result = await _repository.deals();
      if (isClosed) return;
      emit(
        FlightDealsState(
          status: result.deals.isEmpty
              ? FlightDealsStatus.hidden
              : FlightDealsStatus.loaded,
          deals: result.deals,
          personalized: result.personalized,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(const FlightDealsState(status: FlightDealsStatus.hidden));
    }
  }
}
