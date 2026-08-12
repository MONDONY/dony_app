import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/settings/data/models/notification_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/notification_prefs_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'notification_prefs_event.dart';
part 'notification_prefs_state.dart';

class NotificationPrefsBloc
    extends Bloc<NotificationPrefsEvent, NotificationPrefsState> {
  final Box _box;

  /// Dépôt des demandes : porte l'unique réglage de cet écran qui vit côté
  /// serveur (« me prévenir des nouveaux colis compatibles »).
  ///
  /// Requis, et non plus optionnel : en optionnel, un câblage d'injection
  /// oublié ne cassait ni la compilation ni un test, et la cloche devenait
  /// silencieusement inerte en production (chargement sans effet, ligne
  /// définitivement désactivée, tap sans suite). En le rendant requis, l'oubli
  /// devient une erreur de compilation.
  final PackageRequestRepository _packageRequests;
  final AnalyticsService _analytics;

  /// Dépôt des préférences de notification. C'est lui qui rend cet écran
  /// effectif : le filtrage des push est appliqué par le backend
  /// (`FcmService.sendToUser` interroge `NotificationPrefsService.isAllowed`).
  /// Sans cette synchronisation, Hive n'enregistrait qu'un choix décoratif que
  /// le serveur ignorait.
  final NotificationPrefsRepository _prefsRepository;

  /// Défauts locaux, strictement ceux du serveur. `email_promo` a été retiré :
  /// il n'avait ni champ correspondant côté serveur, ni émetteur, ni plus
  /// aucune ligne dans l'écran.
  static const Map<String, bool> _defaults = NotificationPrefsDto.defaults;

  NotificationPrefsBloc(
    this._box,
    this._packageRequests,
    this._analytics,
    this._prefsRepository,
  ) : super(
        NotificationPrefsState(
          prefs: {
            for (final e in _defaults.entries)
              e.key:
                  (_box.get('notif_${e.key}', defaultValue: e.value)
                      as bool?) ??
                  e.value,
          },
        ),
      ) {
    on<NotifPrefsSyncRequested>(_onSync);
    on<NotifPrefToggled>(_onToggled);
    on<NotifPackageMatchAlertLoadRequested>(_onPackageMatchAlertLoad);
    on<NotifPackageMatchAlertToggled>(_onPackageMatchAlertToggled);
  }

  /// Marque qu'un premier échange avec le serveur a réussi. Tant qu'il est
  /// absent, les valeurs Hive sont des choix que l'utilisateur a faits à une
  /// époque où l'écran ne les transmettait pas.
  static const String _syncedOnceKey = 'notif_synced_once';

  /// Le serveur fait autorité : Hive n'est qu'un cache qui permet d'afficher
  /// l'écran immédiatement, et de le laisser lisible hors ligne. Un échec de
  /// lecture conserve donc le cache au lieu de remettre les défauts, qui
  /// afficheraient des réglages que l'utilisateur n'a jamais choisis.
  ///
  /// Exception au tout premier passage : les réglages locaux n'ont jamais été
  /// transmis, le serveur répondrait donc ses défauts et effacerait des choix
  /// déjà exprimés. On les fait d'abord remonter — ce qui, au passage, les rend
  /// enfin effectifs. Le drapeau n'est posé qu'après un envoi réussi, sinon la
  /// reprise se ferait au prochain lancement.
  Future<void> _onSync(
    NotifPrefsSyncRequested event,
    Emitter<NotificationPrefsState> emit,
  ) async {
    emit(state.copyWith(isSyncing: true, errorMessageGetter: () => null));
    try {
      if (_box.get(_syncedOnceKey, defaultValue: false) != true) {
        await _prefsRepository.updatePrefs(NotificationPrefsDto(state.prefs));
        await _box.put(_syncedOnceKey, true);
        emit(state.copyWith(isSyncing: false));
        return;
      }
      final dto = await _prefsRepository.fetchPrefs();
      final merged = Map<String, bool>.from(state.prefs)..addAll(dto.values);
      for (final entry in dto.values.entries) {
        await _box.put('notif_${entry.key}', entry.value);
      }
      emit(state.copyWith(prefs: merged, isSyncing: false));
    } catch (_) {
      emit(state.copyWith(isSyncing: false));
    }
  }

  /// Bascule optimiste : l'interrupteur suit le doigt, puis part au serveur.
  /// Un refus réseau ramène l'interrupteur ET le cache Hive à leur valeur
  /// précédente : laisser Hive en avance sur le serveur ferait réapparaître le
  /// mensonge d'origine, un réglage affiché mais jamais appliqué.
  Future<void> _onToggled(
    NotifPrefToggled event,
    Emitter<NotificationPrefsState> emit,
  ) async {
    if (!state.prefs.containsKey(event.key)) {
      return;
    }
    final previous = state.prefs;
    final enabled = !state.prefs[event.key]!;
    final updated = Map<String, bool>.from(previous)..[event.key] = enabled;
    await _box.put('notif_${event.key}', enabled);
    emit(state.copyWith(prefs: updated, errorMessageGetter: () => null));

    if (!NotificationPrefsDto.isSynced(event.key)) {
      return; // réglage local, rien à pousser
    }

    try {
      await _prefsRepository.updatePrefs(NotificationPrefsDto(updated));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.notificationPrefToggled,
          properties: {'pref': event.key, 'enabled': enabled},
        ),
      );
    } catch (_) {
      await _box.put('notif_${event.key}', previous[event.key]);
      emit(
        state.copyWith(
          prefs: previous,
          errorMessageGetter: () => 'Impossible de synchroniser. Réessayez.',
        ),
      );
    }
  }

  /// Lit l'état serveur de la cloche. Un échec laisse la valeur inconnue : la
  /// ligne reste alors désactivée plutôt que d'afficher un état inventé que
  /// l'utilisateur croirait avoir choisi.
  Future<void> _onPackageMatchAlertLoad(
    NotifPackageMatchAlertLoadRequested event,
    Emitter<NotificationPrefsState> emit,
  ) async {
    try {
      final enabled = await _packageRequests.getPackageMatchAlert();
      emit(state.copyWith(packageMatchAlert: enabled));
    } catch (_) {
      // Valeur inconnue conservée.
    }
  }

  /// Bascule optimiste : l'interrupteur suit le doigt, et revient en arrière
  /// si le serveur refuse.
  Future<void> _onPackageMatchAlertToggled(
    NotifPackageMatchAlertToggled event,
    Emitter<NotificationPrefsState> emit,
  ) async {
    final previous = state.packageMatchAlert;
    emit(state.copyWith(packageMatchAlert: event.enabled));
    try {
      await _packageRequests.setPackageMatchAlert(event.enabled);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.packageMatchAlertToggled,
          properties: {'enabled': event.enabled},
        ),
      );
    } catch (_) {
      // Construction explicite plutôt que `copyWith` : le retour en arrière
      // doit pouvoir restaurer la valeur inconnue (`null`), qu'un paramètre
      // optionnel ne sait pas exprimer.
      emit(
        NotificationPrefsState(
          prefs: state.prefs,
          packageMatchAlert: previous,
          isSyncing: state.isSyncing,
        ),
      );
    }
  }
}
