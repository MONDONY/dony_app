import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';

class AnalyticsBlocObserver extends BlocObserver {
  const AnalyticsBlocObserver(this._analytics);

  final AnalyticsService _analytics;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    final blocName = bloc.runtimeType.toString();
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.blocError,
        properties: {
          'bloc_name': blocName,
          'error_type': error.runtimeType.toString(),
        },
      ),
    );
    // Une erreur BLoC qui remonte jusqu'ici n'a pas été rattrapée par un état
    // Error : c'est un incident à investiguer. On la capture dans Sentry
    // (log + issue avec stacktrace). Pas de PII : seul le nom du BLoC.
    AppLog.error(
      'BLoC error in $blocName',
      error: error,
      stackTrace: stackTrace,
      data: {'bloc_name': blocName},
    );
  }
}
