// ignore_for_file: prefer_const_constructors
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/features/auth/bloc/local_auth_state.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QrScanSuccess', () {
    test('holds event model', () {
      final event = TrackingEventModel(
        id: 'ev-1',
        bidId: 'bid-1',
        eventType: 'TRANSIT',
        scannedAt: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
      );
      final state = QrScanSuccess(event);
      expect(state.event.id, 'ev-1');
    });
  });

  group('QrScanError', () {
    test('holds message', () {
      final state = QrScanError('Scan failed');
      expect(state.message, 'Scan failed');
    });
  });

  group('QrScanSubmitRequested', () {
    test('holds required fields', () {
      final e = QrScanSubmitRequested(
        bidId: 'bid-1',
        eventType: 'TRANSIT',
      );
      expect(e.bidId, 'bid-1');
      expect(e.eventType, 'TRANSIT');
      expect(e.photo, isNull);
    });
  });

  group('LocalAuthError', () {
    test('holds message', () {
      final state = LocalAuthError('Wrong PIN');
      expect(state.message, 'Wrong PIN');
    });
  });

  group('EnvoisRefreshNotifier', () {
    test('requestRefresh notifies listeners', () {
      final notifier = EnvoisRefreshNotifier();
      var called = false;
      notifier.addListener(() => called = true);
      notifier.requestRefresh();
      expect(called, isTrue);
    });
  });
}
