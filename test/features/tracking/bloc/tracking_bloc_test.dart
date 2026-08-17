import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockTrackingRepository extends Mock implements TrackingRepository {}

class MockOfflineSyncService extends Mock implements OfflineSyncService {}

const _qrCode = QrCodeModel(
  bidId: 'bid-1',
  scanUrl: 'https://api.dony.app/scan/abc',
  qrCodeBase64: 'base64==',
);

const _searchResult = TrackingSearchModel(
  trackingNumber: 'DON-ABC123',
  bidId: 'bid-2',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  currentStep: 'IN_TRANSIT',
  stepLabel: 'En transit',
  paymentStatus: 'ESCROW',
);

final _event = TrackingEventModel(
  id: 'ev-1',
  bidId: 'bid-1',
  eventType: 'TRANSIT',
  scannedAt: DateTime(2024, 1, 15, 10),
  createdAt: DateTime(2024, 1, 15, 10),
);

void main() {
  late MockTrackingRepository mockRepo;
  late MockOfflineSyncService mockSync;

  setUp(() {
    mockRepo = MockTrackingRepository();
    mockSync = MockOfflineSyncService();
    when(() => mockSync.pendingCount).thenReturn(0);
    when(() => mockSync.syncAll()).thenAnswer((_) async {});
  });

  TrackingBloc buildBloc() {
    final backend = MockAnalyticsBackend();
    final analytics = makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return TrackingBloc(mockRepo, mockSync, analytics);
  }

  // ── TrackingQrCodeRequested ──────────────────────────────────────────────────

  group('TrackingQrCodeRequested', () {
    blocTest<TrackingBloc, TrackingState>(
      'emits [QrLoading, QrLoaded] on success',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getQrCode('bid-1'),
        ).thenAnswer((_) async => _qrCode);
      },
      act: (b) => b.add(TrackingQrCodeRequested('bid-1')),
      expect: () => [
        isA<TrackingQrLoading>(),
        isA<TrackingQrLoaded>().having((s) => s.qrCode.bidId, 'bidId', 'bid-1'),
      ],
    );

    blocTest<TrackingBloc, TrackingState>(
      'emits [QrLoading, QrError] on failure',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getQrCode(any())).thenThrow(Exception('not found'));
      },
      act: (b) => b.add(TrackingQrCodeRequested('bid-x')),
      expect: () => [isA<TrackingQrLoading>(), isA<TrackingQrError>()],
    );
  });

  // ── TrackingSearchRequested ──────────────────────────────────────────────────

  group('TrackingSearchRequested', () {
    blocTest<TrackingBloc, TrackingState>(
      'emits [SearchLoading, SearchLoaded] on success',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.searchByTrackingNumber('DON-ABC123'),
        ).thenAnswer((_) async => _searchResult);
      },
      act: (b) => b.add(TrackingSearchRequested('DON-ABC123')),
      expect: () => [
        isA<TrackingSearchLoading>(),
        isA<TrackingSearchLoaded>().having(
          (s) => s.result.trackingNumber,
          'trackingNumber',
          'DON-ABC123',
        ),
      ],
    );

    blocTest<TrackingBloc, TrackingState>(
      'emits [SearchLoading, SearchError] on failure',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.searchByTrackingNumber(any()),
        ).thenThrow(Exception('not found'));
      },
      act: (b) => b.add(TrackingSearchRequested('DON-XXXX')),
      expect: () => [isA<TrackingSearchLoading>(), isA<TrackingSearchError>()],
    );
  });

  // ── TrackingEventsRequested ──────────────────────────────────────────────────

  group('TrackingEventsRequested', () {
    blocTest<TrackingBloc, TrackingState>(
      'emits [EventsLoading, EventsLoaded] on success',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getEvents('bid-1'),
        ).thenAnswer((_) async => [_event]);
      },
      act: (b) => b.add(TrackingEventsRequested('bid-1')),
      expect: () => [
        isA<TrackingEventsLoading>(),
        isA<TrackingEventsLoaded>().having(
          (s) => s.events,
          'events',
          hasLength(1),
        ),
      ],
    );

    blocTest<TrackingBloc, TrackingState>(
      'emits [EventsLoading, EventsError] on generic failure',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getEvents(any()),
        ).thenThrow(Exception('server error'));
      },
      act: (b) => b.add(TrackingEventsRequested('bid-x')),
      expect: () => [isA<TrackingEventsLoading>(), isA<TrackingEventsError>()],
    );

    blocTest<TrackingBloc, TrackingState>(
      'emits [EventsLoading, EventsError] on ForbiddenException',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getEvents(any()),
        ).thenThrow(const ForbiddenException());
      },
      act: (b) => b.add(TrackingEventsRequested('bid-no-access')),
      expect: () => [
        isA<TrackingEventsLoading>(),
        isA<TrackingEventsError>().having(
          (s) => s.error,
          'error',
          isA<ForbiddenException>(),
        ),
      ],
    );

    blocTest<TrackingBloc, TrackingState>(
      'emits [EventsLoading, EventsError] on UnauthorizedException',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getEvents(any()),
        ).thenThrow(const UnauthorizedException());
      },
      act: (b) => b.add(TrackingEventsRequested('bid-expired')),
      expect: () => [
        isA<TrackingEventsLoading>(),
        isA<TrackingEventsError>().having(
          (s) => s.error,
          'error',
          isA<UnauthorizedException>(),
        ),
      ],
    );

    blocTest<TrackingBloc, TrackingState>(
      '404 → TrackingEventsError avec NotFoundException',
      build: buildBloc,
      setUp: () => when(() => mockRepo.getEvents(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bids/bid-1/events'),
          error: const NotFoundException(),
        ),
      ),
      act: (bloc) => bloc.add(TrackingEventsRequested('bid-1')),
      expect: () => [
        isA<TrackingEventsLoading>(),
        predicate<TrackingState>(
          (s) => s is TrackingEventsError && s.error is NotFoundException,
        ),
      ],
    );
  });

  // ── ConfirmDeliveryRequested ──────────────────────────────────────────────────

  group('ConfirmDeliveryRequested', () {
    blocTest<TrackingBloc, TrackingState>(
      'emits [DeliveryConfirmLoading, DeliveryConfirmSuccess] on success',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.confirmDelivery(bidId: 'bid-1', code: '4721'),
        ).thenAnswer((_) async => _event);
      },
      act: (b) => b.add(ConfirmDeliveryRequested(bidId: 'bid-1', code: '4721')),
      expect: () => [
        isA<DeliveryConfirmLoading>(),
        isA<DeliveryConfirmSuccess>().having(
          (s) => s.event.bidId,
          'bidId',
          'bid-1',
        ),
      ],
    );

    blocTest<TrackingBloc, TrackingState>(
      'emits [DeliveryConfirmLoading, DeliveryConfirmError] on failure',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.confirmDelivery(
            bidId: any(named: 'bidId'),
            code: any(named: 'code'),
          ),
        ).thenThrow(const ValidationException('Code invalide'));
      },
      act: (b) => b.add(ConfirmDeliveryRequested(bidId: 'bid-1', code: '9999')),
      expect: () => [
        isA<DeliveryConfirmLoading>(),
        isA<DeliveryConfirmError>().having(
          (s) => s.error.message,
          'message',
          'Code invalide',
        ),
      ],
    );
  });

  // ── QrScanSubmitRequested ─────────────────────────────────────────────────────

  group('QrScanSubmitRequested', () {
    // Connectivity() uses a platform channel — in unit tests it throws
    // MissingPluginException, landing in the catch block and emitting QrScanError.
    blocTest<TrackingBloc, TrackingState>(
      'emits [QrScanSubmitting, QrScanError] when connectivity platform channel unavailable',
      build: buildBloc,
      act: (b) =>
          b.add(QrScanSubmitRequested(bidId: 'bid-1', eventType: 'TRANSIT')),
      expect: () => [isA<QrScanSubmitting>(), isA<QrScanError>()],
    );
  });

  // ── OfflineSyncRequested ──────────────────────────────────────────────────────

  group('OfflineSyncRequested', () {
    blocTest<TrackingBloc, TrackingState>(
      'emits [SyncInProgress, SyncDone] and calls syncAll',
      build: buildBloc,
      setUp: () {
        when(() => mockSync.pendingCount).thenReturn(3);
        when(() => mockSync.syncAll()).thenAnswer((_) async {});
      },
      act: (b) => b.add(OfflineSyncRequested()),
      expect: () => [isA<OfflineSyncInProgress>(), isA<OfflineSyncDone>()],
      verify: (_) {
        verify(() => mockSync.syncAll()).called(1);
      },
    );
  });
}
