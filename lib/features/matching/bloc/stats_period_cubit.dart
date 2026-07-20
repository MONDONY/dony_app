import 'package:flutter_bloc/flutter_bloc.dart';

/// Intervalle de temps des statistiques du hub Activités.
enum StatsPeriod { sevenDays, thirtyDays, twelveMonths }

extension StatsPeriodX on StatsPeriod {
  /// Valeur envoyée au backend.
  String get apiValue => switch (this) {
    StatsPeriod.sevenDays => '7d',
    StatsPeriod.thirtyDays => '30d',
    StatsPeriod.twelveMonths => '12m',
  };

  String get label => switch (this) {
    StatsPeriod.sevenDays => '7 jours',
    StatsPeriod.thirtyDays => '30 jours',
    StatsPeriod.twelveMonths => '12 mois',
  };
}

/// Porte la période sélectionnée. Aucun appel réseau : le hub écoute ce cubit
/// et relance [TripsSummaryCubit.load] au changement.
class StatsPeriodCubit extends Cubit<StatsPeriod> {
  StatsPeriodCubit() : super(StatsPeriod.thirtyDays);

  void select(StatsPeriod period) {
    if (period != state) emit(period);
  }
}
