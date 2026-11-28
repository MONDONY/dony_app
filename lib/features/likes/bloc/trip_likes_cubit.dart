import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/likes/data/models/trip_like_status.dart';
import 'package:dony/features/likes/data/repositories/trip_like_repository.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TripLikesState extends Equatable {
  const TripLikesState({this.byTrip = const {}});

  final Map<String, TripLikeStatus> byTrip;

  @override
  List<Object?> get props => [byTrip];
}

/// Source de vérité des « j'aime » des cartes de trajet, partagée par toute
/// l'app (singleton GetIt, fourni dans `app.dart`).
class TripLikesCubit extends Cubit<TripLikesState> {
  TripLikesCubit(this._repo, this._analytics, {this.onLiked})
    : super(const TripLikesState());

  final TripLikeRepository _repo;
  final AnalyticsService _analytics;

  /// Appelé après chaque « j'aime » confirmé par le serveur. L'app s'en sert
  /// pour proposer la bulle qui explique les favoris.
  final void Function()? onLiked;

  /// Trajets dont un appel est en cours.
  final Set<String> _inFlight = {};

  /// Trajets basculés avec succès par [toggle] pendant cette session : ils ne
  /// sont jamais écrasés par [seed] (la recherche du back est mise en cache
  /// jusqu'à 5 minutes, une liste rechargée peut porter d'anciennes valeurs).
  /// Une bascule en échec, revenue à l'état d'avant, n'y laisse pas le trajet.
  final Set<String> _touched = {};

  /// Incrémenté par [reset] : une réponse tardive d'un ancien compte est
  /// ignorée.
  int _epoch = 0;

  TripLikeStatus statusOf(AnnouncementModel trip) =>
      state.byTrip[trip.id] ??
      TripLikeStatus(likeCount: trip.likeCount, likedByMe: trip.likedByMe);

  /// Ajoute les trajets inconnus et rafraîchit ceux jamais basculés ici.
  void seed(Iterable<AnnouncementModel> trips) {
    var next = state.byTrip;
    var changed = false;
    for (final t in trips) {
      if (_touched.contains(t.id) || _inFlight.contains(t.id)) continue;
      final status = TripLikeStatus(
        likeCount: t.likeCount,
        likedByMe: t.likedByMe,
      );
      if (next[t.id] == status) continue;
      if (!changed) next = Map.of(next);
      next[t.id] = status;
      changed = true;
    }
    if (changed) emit(TripLikesState(byTrip: next));
  }

  /// Bascule optimiste. Retour arrière puis `rethrow` en cas d'erreur.
  Future<void> toggle(AnnouncementModel trip) async {
    final id = trip.id;
    if (_inFlight.contains(id)) return;
    final epoch = _epoch;
    final before = statusOf(trip);
    final adding = !before.likedByMe;
    _inFlight.add(id);
    // Faux si une bascule réussie l'y a déjà mis : un échec ne l'en retire
    // pas, sa valeur confirmée reste protégée de [seed].
    final firstTouch = _touched.add(id);
    _put(
      id,
      TripLikeStatus(
        likeCount: adding
            ? before.likeCount + 1
            : (before.likeCount - 1).clamp(0, 1 << 30),
        likedByMe: adding,
      ),
    );
    try {
      final server = adding ? await _repo.like(id) : await _repo.unlike(id);
      if (epoch != _epoch) return;
      _put(id, server);
      unawaited(
        _analytics.logEvent(
          adding ? AnalyticsEvents.tripLiked : AnalyticsEvents.tripUnliked,
        ),
      );
      if (adding) onLiked?.call();
    } catch (e) {
      if (epoch == _epoch) {
        _put(id, before);
        // Rien n'a changé côté serveur : une liste relue peut de nouveau
        // rafraîchir ce trajet.
        if (firstTouch) _touched.remove(id);
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.tripLikeFailed,
            properties: {
              'error_code': (e is AppException ? e.code : null) ?? 'unknown',
            },
          ),
        );
      }
      rethrow;
    } finally {
      if (epoch == _epoch) _inFlight.remove(id);
    }
  }

  /// Vide tout à la déconnexion ou au changement de compte.
  void reset() {
    _epoch++;
    _inFlight.clear();
    _touched.clear();
    emit(const TripLikesState());
  }

  void trackLoginPrompted() =>
      unawaited(_analytics.logEvent(AnalyticsEvents.tripLikeLoginPrompted));

  void trackShareTapped() =>
      unawaited(_analytics.logEvent(AnalyticsEvents.tripCardShareTapped));

  void _put(String id, TripLikeStatus s) =>
      emit(TripLikesState(byTrip: {...state.byTrip, id: s}));
}
