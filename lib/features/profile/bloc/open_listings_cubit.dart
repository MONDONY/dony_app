import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/data/models/open_listing.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Filtre de la section « En cours » d'un profil.
enum OpenListingsFilter { all, trips, requests }

sealed class OpenListingsState {
  const OpenListingsState();
}

class OpenListingsInitial extends OpenListingsState {
  const OpenListingsInitial();
}

class OpenListingsLoading extends OpenListingsState {
  const OpenListingsLoading();
}

class OpenListingsLoaded extends OpenListingsState {
  const OpenListingsLoaded({
    required this.items,
    this.filter = OpenListingsFilter.all,
    this.expanded = true,
  });

  /// Toutes les annonces ouvertes, de la plus récente à la plus ancienne.
  final List<OpenListing> items;
  final OpenListingsFilter filter;

  /// Section dépliée (par défaut) ou repliée sur son seul en-tête : le profil
  /// est long, replier laisse atteindre les avis sans défiler jusqu'en bas.
  final bool expanded;

  int get tripCount => items.whereType<OpenTripListing>().length;
  int get requestCount => items.whereType<OpenRequestListing>().length;

  /// Annonces affichées sous le filtre courant, ordre conservé.
  List<OpenListing> get visible => switch (filter) {
    OpenListingsFilter.all => items,
    OpenListingsFilter.trips => items.whereType<OpenTripListing>().toList(),
    OpenListingsFilter.requests =>
      items.whereType<OpenRequestListing>().toList(),
  };

  OpenListingsLoaded withFilter(OpenListingsFilter next) =>
      OpenListingsLoaded(items: items, filter: next, expanded: expanded);

  OpenListingsLoaded withExpanded({required bool value}) =>
      OpenListingsLoaded(items: items, filter: filter, expanded: value);
}

/// Échec (réseau, back pas encore déployé) : la section se masque, le reste
/// du profil n'est pas touché.
class OpenListingsFailed extends OpenListingsState {
  const OpenListingsFailed();
}

/// Annonces ouvertes d'un membre, pour la section « En cours » de son profil.
class OpenListingsCubit extends Cubit<OpenListingsState> {
  OpenListingsCubit(this._repository, this._analytics)
    : super(const OpenListingsInitial());

  final ProfileRepository _repository;
  final AnalyticsService _analytics;

  Future<void> load(String userId) async {
    if (userId.isEmpty) return;
    emit(const OpenListingsLoading());
    try {
      final items = await _repository.getOpenListings(userId);
      if (isClosed) return;
      final loaded = OpenListingsLoaded(items: items);
      emit(loaded);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.openListingsViewed,
          properties: {
            'trip_count': loaded.tripCount,
            'request_count': loaded.requestCount,
          },
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(const OpenListingsFailed());
    }
  }

  void selectFilter(OpenListingsFilter filter) {
    final current = state;
    if (current is! OpenListingsLoaded || current.filter == filter) return;
    emit(current.withFilter(filter));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.openListingsFilterChanged,
        properties: {'filter': filter.name},
      ),
    );
  }

  /// Replie ou déplie la section depuis son en-tête. Le filtre choisi est gardé.
  void toggleExpanded() {
    final current = state;
    if (current is! OpenListingsLoaded) return;
    final next = current.withExpanded(value: !current.expanded);
    emit(next);
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.openListingsToggled,
        properties: {'expanded': next.expanded},
      ),
    );
  }

  /// Une carte de la section a été ouverte (`trip` ou `request`).
  void trackOpened(String kind) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.openListingOpened,
        properties: {'kind': kind},
      ),
    );
  }
}
