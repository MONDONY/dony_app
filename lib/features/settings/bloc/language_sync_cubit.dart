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
///   répondrait 403/404 pour une session sans compte.
/// - `effective` déjà égale à `user.preferredLanguage` : aucun appel, l'état
///   passe directement à `synced`. C'est le cas courant tant que
///   `kEnglishEnabled` est faux : la langue effective est alors toujours
///   `fr`, déjà la valeur par défaut côté serveur.
/// - `effective` déjà tentée dans cette session (succès ou 404 de
///   compatibilité) : aucun appel supplémentaire.
class LanguageSyncCubit extends Cubit<LanguageSyncState> {
  LanguageSyncCubit(this._repository, this._analytics)
    : super(const LanguageSyncState());

  final UserLanguageRepository _repository;
  final AnalyticsService _analytics;

  /// Langues déjà tentées dans cette session (succès ou 404 backend ancien) :
  /// jamais retentées. Une exception réseau, elle, n'y entre pas — elle doit
  /// se réessayer au prochain `sync` (démarrage suivant ou nouveau
  /// changement de langue), sans jamais remonter d'erreur à l'utilisateur.
  final Set<String> _attempted = {};

  Future<void> sync({
    required String effective,
    required UserModel? user,
  }) async {
    if (user == null) return;

    if (effective == user.preferredLanguage) {
      emit(LanguageSyncState(synced: effective));
      return;
    }
    if (_attempted.contains(effective)) return;

    try {
      final confirmed = await _repository.update(effective);
      // Compte à jour même sur un 404 (backend ancien) : pas de relance à
      // chaque frame tant que ce backend n'aura pas été mis à jour.
      _attempted.add(effective);
      if (confirmed) {
        emit(LanguageSyncState(synced: effective));
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.preferredLanguageSynced,
            properties: {'language': effective},
          ),
        );
      }
    } catch (_) {
      // Erreur réseau/serveur : jamais remontée à l'utilisateur pour une
      // synchro en arrière-plan. La tentative n'est pas mémorisée, pour
      // réessayer au prochain sync.
    }
  }
}
