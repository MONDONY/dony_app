import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'notification_prefs_event.dart';
part 'notification_prefs_state.dart';

class NotificationPrefsBloc
    extends Bloc<NotificationPrefsEvent, NotificationPrefsState> {
  final Box _box;

  /// Dépôt des demandes : porte l'unique réglage de cet écran qui vit côté
  /// serveur (« me prévenir des nouveaux colis compatibles »). Optionnel pour
  /// que les tests qui ne s'intéressent qu'aux préférences Hive n'aient rien à
  /// injecter.
  final PackageRequestRepository? _packageRequests;
  final AnalyticsService? _analytics;

  static const Map<String, bool> _defaults = {
    'push_activity_bids': true,
    'push_activity_negotiations': true,
    'push_messages': true,
    'push_trip_reminder': true,
    'push_promo': false,
    'email_promo': false,
  };

  NotificationPrefsBloc(this._box, [this._packageRequests, this._analytics])
      : super(NotificationPrefsState(
          prefs: {
            for (final e in _defaults.entries)
              e.key: (_box.get(
                    'notif_${e.key}',
                    defaultValue: e.value,
                  ) as bool?) ?? e.value,
          },
        )) {
    on<NotifPrefToggled>(_onToggled);
    on<NotifPackageMatchAlertLoadRequested>(_onPackageMatchAlertLoad);
    on<NotifPackageMatchAlertToggled>(_onPackageMatchAlertToggled);
  }

  void _onToggled(
    NotifPrefToggled event,
    Emitter<NotificationPrefsState> emit,
  ) {
    if (!state.prefs.containsKey(event.key)) {
      return;
    }
    final updated = Map<String, bool>.from(state.prefs);
    updated[event.key] = !state.prefs[event.key]!;
    _box.put('notif_${event.key}', updated[event.key]);
    emit(state.copyWith(prefs: updated));
  }

  /// Lit l'état serveur de la cloche. Un échec laisse la valeur inconnue : la
  /// ligne reste alors désactivée plutôt que d'afficher un état inventé que
  /// l'utilisateur croirait avoir choisi.
  Future<void> _onPackageMatchAlertLoad(
    NotifPackageMatchAlertLoadRequested event,
    Emitter<NotificationPrefsState> emit,
  ) async {
    final repository = _packageRequests;
    if (repository == null) {
      return;
    }
    try {
      final enabled = await repository.getPackageMatchAlert();
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
    final repository = _packageRequests;
    if (repository == null) {
      return;
    }
    final previous = state.packageMatchAlert;
    emit(state.copyWith(packageMatchAlert: event.enabled));
    try {
      await repository.setPackageMatchAlert(event.enabled);
      unawaited(_analytics?.logEvent(
        AnalyticsEvents.packageMatchAlertToggled,
        properties: {'enabled': event.enabled},
      ));
    } catch (_) {
      // Construction explicite plutôt que `copyWith` : le retour en arrière
      // doit pouvoir restaurer la valeur inconnue (`null`), qu'un paramètre
      // optionnel ne sait pas exprimer.
      emit(NotificationPrefsState(
        prefs: state.prefs,
        packageMatchAlert: previous,
      ));
    }
  }
}
