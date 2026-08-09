import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';

class AnalyticsBlocObserver extends BlocObserver {
  const AnalyticsBlocObserver(this._analytics, [this._errorReporter]);

  final AnalyticsService _analytics;
  final ErrorReportingService? _errorReporter;

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
    unawaited(
      _errorReporter?.report(
        error,
        operation: 'bloc.$blocName',
        stackTrace: stackTrace,
        context: {'feature': blocName},
      ),
    );
  }
}
