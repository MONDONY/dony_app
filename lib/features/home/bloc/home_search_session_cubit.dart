import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dernière recherche de l'onglet Rechercher : filtres et mode.
///
/// `null` tant que l'onglet n'a rien réglé dans la session.
class HomeSearchSessionState {
  const HomeSearchSessionState({this.filters, this.mode});

  final HomeSearchFilters? filters;
  final SearchMode? mode;
}

/// Mémoire de la recherche pour la durée de la session (singleton GetIt).
///
/// L'écran Rechercher vit dans la branche du shell : une navigation par
/// `go()` vers une page hors du shell (paiement d'une demande, notification,
/// écran de succès, retour système vers `/home`) détruit le shell, et l'écran
/// recréé repartait de filtres vides, filtre Transport compris. L'écran
/// relit donc sa dernière recherche ici à sa création.
///
/// Remise à zéro à la déconnexion ou au changement de compte.
class HomeSearchSessionCubit extends Cubit<HomeSearchSessionState> {
  HomeSearchSessionCubit() : super(const HomeSearchSessionState());

  void remember({
    required HomeSearchFilters filters,
    required SearchMode mode,
  }) => emit(HomeSearchSessionState(filters: filters, mode: mode));

  void reset() => emit(const HomeSearchSessionState());
}
