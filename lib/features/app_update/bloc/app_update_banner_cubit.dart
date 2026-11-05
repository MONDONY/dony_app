import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/app_update/data/services/app_store_launcher.dart';
import 'package:dony/features/app_update/data/services/app_update_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Visibilité du bandeau de mise à jour douce : `true` tant qu'une version
/// recommandée plus récente existe et que l'utilisateur ne l'a pas fermé.
///
/// La fermeture ne dure que le temps de la session : le bandeau revient au
/// prochain lancement tant que l'application n'est pas à jour.
class AppUpdateBannerCubit extends Cubit<bool> {
  AppUpdateBannerCubit(
    this._service,
    this._analytics, {
    Future<void> Function()? openStore,
  }) : _openStore = openStore ?? AppStoreLauncher.open,
       super(false);

  final AppUpdateService _service;
  final AnalyticsService _analytics;
  final Future<void> Function() _openStore;

  Future<void> check() async {
    final recommended = await _service.isUpdateRecommended();
    if (isClosed) return;
    emit(recommended);
    if (recommended) {
      unawaited(_analytics.logEvent(AnalyticsEvents.appUpdateBannerShown));
    }
  }

  Future<void> openStore() {
    unawaited(_analytics.logEvent(AnalyticsEvents.appUpdateBannerTapped));
    return _openStore();
  }

  void dismiss() {
    if (!state) return;
    unawaited(_analytics.logEvent(AnalyticsEvents.appUpdateBannerDismissed));
    emit(false);
  }
}
