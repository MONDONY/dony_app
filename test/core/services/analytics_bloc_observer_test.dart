import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_bloc_observer.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/mock_analytics_backend.dart';

class _FakeBloc extends Fake implements BlocBase<Object?> {
  @override
  Type get runtimeType => _FakeBloc;
}

class _Sink implements ErrorReportingSink {
  int calls = 0;

  @override
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  }) async {
    calls++;
  }
}

void main() {
  late MockAnalyticsBackend backend;

  setUp(() {
    backend = MockAnalyticsBackend();
  });

  test(
    'onError captures bloc_error event with bloc_name and error_type',
    () async {
      final analytics = makeEnabledAnalytics(backend);
      await analytics.onConfigured();
      clearInteractions(backend);

      final observer = AnalyticsBlocObserver(analytics);
      final fakeBloc = _FakeBloc();
      final error = Exception('test error');

      observer.onError(fakeBloc, error, StackTrace.empty);

      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.blocError, {
          'bloc_name': '_FakeBloc',
          'error_type': '_Exception',
        }),
      ).called(1);
    },
  );

  test('onError is no-op when analytics disabled', () async {
    final analytics = makeDisabledAnalytics(backend);
    await analytics.onConfigured();
    clearInteractions(backend);

    final observer = AnalyticsBlocObserver(analytics);
    observer.onError(_FakeBloc(), Exception('x'), StackTrace.empty);

    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });

  test('reports uncaught bloc errors without depending on PostHog', () async {
    final analytics = makeDisabledAnalytics(backend);
    await analytics.onConfigured();
    final sink = _Sink();
    final observer = AnalyticsBlocObserver(
      analytics,
      ErrorReportingService(sink),
    );

    observer.onError(_FakeBloc(), StateError('secret'), StackTrace.current);
    await Future<void>.delayed(Duration.zero);

    expect(sink.calls, 1);
  });
}
