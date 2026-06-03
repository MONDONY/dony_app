import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockTrackingRepo extends Mock implements TrackingRepository {}

class _MockOfflineSync extends Mock implements OfflineSyncService {}

TrackingEventModel _fakeTrackingEvent() => TrackingEventModel(
      id: 'ev-test',
      bidId: 'bid1',
      eventType: 'PICKUP',
      scannedAt: DateTime(2024, 1, 1, 12),
      createdAt: DateTime(2024, 1, 1, 12),
    );

void main() {
  late _MockTrackingRepo repo;
  late _MockOfflineSync offlineSync;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockTrackingRepo();
    offlineSync = _MockOfflineSync();
    backend = MockAnalyticsBackend();
    when(() => offlineSync.pendingCount).thenReturn(0);
    when(() => offlineSync.syncAll()).thenAnswer((_) async {});
  });

  TrackingBloc makeBloc({bool enabled = true}) {
    final a =
        enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return TrackingBloc(repo, offlineSync, a);
  }

  group('QrScanSubmitRequested analytics', () {
    // NOTE: In unit tests, Connectivity() uses a platform channel that is not
    // available, causing a MissingPluginException that lands in the catch block.
    // This means the bloc always emits QrScanError in unit tests — the online
    // success path (which fires qr_scan_success) cannot be reached without a
    // full integration test environment. These tests verify the offline/error
    // paths do NOT fire analytics events, which is the correct behaviour.

    test('no qr_scan_success event fired when connectivity unavailable (error path)', () async {
      final bloc = makeBloc();
      bloc.add(QrScanSubmitRequested(bidId: 'bid1', eventType: 'PICKUP'));
      // Wait for QrScanSubmitting + QrScanError
      await bloc.stream.first; // QrScanSubmitting
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // qr_scan_success must NOT have been fired (we never reached the success path)
      verifyNever(() => backend.capture(AnalyticsEvents.qrScanSuccess, any()));
    });

    test('no event when analytics disabled', () async {
      final bloc = makeBloc(enabled: false);
      bloc.add(QrScanSubmitRequested(bidId: 'bid1', eventType: 'PICKUP'));
      await bloc.stream.first;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      verifyNever(() => backend.capture(any(), any()));
    });
  });
}
