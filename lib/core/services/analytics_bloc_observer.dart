import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';

class AnalyticsBlocObserver extends BlocObserver {
  const AnalyticsBlocObserver(this._analytics);

  final AnalyticsService _analytics;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    unawaited(_analytics.logEvent(
      AnalyticsEvents.blocError,
      properties: {
        'bloc_name': bloc.runtimeType.toString(),
        'error_type': error.runtimeType.toString(),
      },
    ));
  }
}
