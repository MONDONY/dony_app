import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/language_sync_state.dart';
import 'package:dony/features/settings/data/repositories/user_language_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Synchronise la langue effective de l'app (`fr`/`en` résolue, jamais
/// `system`) avec `preferredLanguage` du compte serveur.
///
/// - `user == null` (invité ou déconnecté) : aucun appel — le serveur
///   répondrait 403/404 pour une session sans compte. L'état interne (compte
///   suivi, dernière langue serveur connue, backend sans route) est remis à
///   zéro.
/// - Un compte différent (`user.id` change) : même remise à zéro,
///   réinitialisée à partir de `user.preferredLanguage`. Ce cubit est un
///   singleton d'app (fourni à la racine, vit toute la session) : sans cette
///   remise à zéro, la langue déjà tentée par le compte précédent bloquait
///   la synchro du suivant (relecture finale, constat Important).
/// - `effective` déjà égale à la dernière langue **serveur connue** (pas
///   `user.preferredLanguage`, qui ne se met jamais à jour dans `AuthBloc`
///   après ce PATCH et deviendrait périmée dès le deuxième changement) :
///   aucun appel. C'est le cas courant tant que `kEnglishEnabled` est faux.
/// - Un appel est déjà en vol pour cette langue : aucun second PATCH (deux
///   transitions `AuthBloc` rapprochées au démarrage, par exemple).
/// - Le backend ne connaît pas encore la route (404 une fois) : plus aucun
///   appel pour le reste de la session, quelle que soit la langue demandée
///   ensuite — seul un 404 doit bloquer les relances, jamais une exception.
class LanguageSyncCubit extends Cubit<LanguageSyncState> {
  LanguageSyncCubit(this._repository, this._analytics)
    : super(const LanguageSyncState());

  final UserLanguageRepository _repository;
  final AnalyticsService _analytics;

  /// Compte actuellement suivi. `null` tant qu'aucun `sync` avec utilisateur
  /// n'a eu lieu, ou après une déconnexion.
  String? _userId;

  /// Dernière langue connue côté serveur pour [_userId] : initialisée à
  /// `user.preferredLanguage` au premier `sync` de ce compte, puis mise à
  /// jour après chaque PATCH réussi — jamais relue depuis `user.preferredLanguage`
  /// ensuite, qui resterait périmé.
  String? _serverLanguage;

  /// Backend qui ne connaît pas la route (404) : posé une fois pour la
  /// session entière du compte courant, jamais réinitialisé sauf changement
  /// de compte ou déconnexion.
  bool _endpointMissing = false;

  /// Langue dont le PATCH est actuellement en vol, pour ignorer un `sync`
  /// concurrent pour cette même langue.
  String? _inFlight;

  Future<void> sync({
    required String effective,
    required UserModel? user,
  }) async {
    if (user == null) {
      _resetTrackedUser(null);
      return;
    }
    if (user.id != _userId) {
      _resetTrackedUser(user);
    }

    if (effective == _serverLanguage) {
      emit(LanguageSyncState(synced: effective));
      return;
    }
    if (_endpointMissing || _inFlight == effective) return;

    _inFlight = effective;
    try {
      final confirmed = await _repository.update(effective);
      if (confirmed) {
        _serverLanguage = effective;
        emit(LanguageSyncState(synced: effective));
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.preferredLanguageSynced,
            properties: {'language': effective},
          ),
        );
      } else {
        _endpointMissing = true;
      }
    } catch (_) {
      // Erreur réseau/serveur : jamais remontée à l'utilisateur pour une
      // synchro en arrière-plan. `_endpointMissing` n'est pas posé : le
      // prochain `sync` (démarrage suivant ou nouveau changement de langue)
      // retente.
    } finally {
      _inFlight = null;
    }
  }

  void _resetTrackedUser(UserModel? user) {
    _userId = user?.id;
    _serverLanguage = user?.preferredLanguage;
    _endpointMissing = false;
    _inFlight = null;
  }
}
