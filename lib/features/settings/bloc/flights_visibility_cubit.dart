import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Préférence « Afficher les billets d'avion » de Paramètres › Apparence,
/// propre à l'appareil (box Hive `user_prefs`). Activée par défaut.
///
/// Éteinte, le hub Activités masque le bloc « Billets d'avion » et la ligne
/// « Alertes prix vols » et ne charge plus leurs données. Les routes
/// `/flights...` restent ouvertes (deep links, notification d'alerte prix) et
/// les alertes existantes continuent côté serveur.
///
/// État : `true` quand les billets sont visibles.
class FlightsVisibilityCubit extends Cubit<bool> {
  FlightsVisibilityCubit(this._box, this._analytics)
    : super(_box.get(HiveService.kFlightsVisible, defaultValue: true) as bool);

  final Box _box;
  final AnalyticsService _analytics;

  Future<void> setVisible(bool visible) async {
    if (visible == state) return;
    emit(visible);
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.settingsFlightsVisibilityChanged,
        properties: {'visible': visible},
      ),
    );
    await _box.put(HiveService.kFlightsVisible, visible);
  }
}
