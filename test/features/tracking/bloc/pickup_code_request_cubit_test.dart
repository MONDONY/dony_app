import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tracking/bloc/pickup_code_request_cubit.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTrackingRepository extends Mock implements TrackingRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

/// Erreur telle que la rend l'intercepteur : l'[AppException] typée dans
/// `error`, le ProblemDetail brut dans `response`.
DioException _httpError(
  int status,
  AppException mapped, [
  Map<String, dynamic>? body,
]) {
  final options = RequestOptions(path: '/tracking/bid-1/request-code');
  return DioException(
    requestOptions: options,
    error: mapped,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  late MockTrackingRepository repository;
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockTrackingRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  void stub(Future<PickupCodeRequestResult> Function() answer) {
    when(() => repository.requestNewCode(any())).thenAnswer((_) => answer());
  }

  blocTest<PickupCodeRequestCubit, PickupCodeRequestState>(
    'succès : demande envoyée, analytics source + issue',
    build: () {
      stub(
        () async => (
          requestedAt: DateTime.utc(2026, 10, 9, 10),
          nextRequestAllowedAt: DateTime.utc(2026, 10, 9, 10, 15),
        ),
      );
      return PickupCodeRequestCubit(repository, analytics);
    },
    act: (cubit) => cubit.request('bid-1', source: 'scan_confirm'),
    expect: () => [
      isA<PickupCodeRequestSending>(),
      isA<PickupCodeRequestSent>().having(
        (s) => s.nextRequestAllowedAt,
        'next',
        DateTime.utc(2026, 10, 9, 10, 15),
      ),
    ],
    verify: (_) {
      verify(() => repository.requestNewCode('bid-1')).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.pickupCodeRequested,
          properties: {'source': 'scan_confirm', 'outcome': 'sent'},
        ),
      ).called(1);
    },
  );

  blocTest<PickupCodeRequestCubit, PickupCodeRequestState>(
    '429 code-request-too-soon : lit nextRequestAllowedAt',
    build: () {
      stub(
        () async => throw _httpError(429, const RateLimitException(), {
          'code': 'code-request-too-soon',
          'nextRequestAllowedAt': '2026-10-09T10:15:00Z',
          'retryAfterSeconds': 540,
        }),
      );
      return PickupCodeRequestCubit(repository, analytics);
    },
    act: (cubit) => cubit.request('bid-1', source: 'bid_detail'),
    expect: () => [
      isA<PickupCodeRequestSending>(),
      isA<PickupCodeRequestTooSoon>().having(
        (s) => s.nextRequestAllowedAt,
        'next',
        DateTime.utc(2026, 10, 9, 10, 15),
      ),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.pickupCodeRequested,
        properties: {'source': 'bid_detail', 'outcome': 'too_soon'},
      ),
    ).called(1),
  );

  blocTest<PickupCodeRequestCubit, PickupCodeRequestState>(
    '429 sans date lisible : échéance inconnue',
    build: () {
      stub(
        () async => throw _httpError(429, const RateLimitException(), {
          'nextRequestAllowedAt': 'pas une date',
        }),
      );
      return PickupCodeRequestCubit(repository, analytics);
    },
    act: (cubit) => cubit.request('bid-1', source: 'scan_confirm'),
    expect: () => [
      isA<PickupCodeRequestSending>(),
      isA<PickupCodeRequestTooSoon>().having(
        (s) => s.nextRequestAllowedAt,
        'next',
        isNull,
      ),
    ],
  );

  blocTest<PickupCodeRequestCubit, PickupCodeRequestState>(
    'RateLimitException sans réponse : échéance inconnue',
    build: () {
      stub(() async => throw const RateLimitException());
      return PickupCodeRequestCubit(repository, analytics);
    },
    act: (cubit) => cubit.request('bid-1', source: 'scan_confirm'),
    expect: () => [
      isA<PickupCodeRequestSending>(),
      isA<PickupCodeRequestTooSoon>().having(
        (s) => s.nextRequestAllowedAt,
        'next',
        isNull,
      ),
    ],
  );

  blocTest<PickupCodeRequestCubit, PickupCodeRequestState>(
    '409 code-still-valid : échec typé avec le code',
    build: () {
      stub(
        () async => throw _httpError(
          409,
          const ConflictException('x', code: 'code-still-valid'),
        ),
      );
      return PickupCodeRequestCubit(repository, analytics);
    },
    act: (cubit) => cubit.request('bid-1', source: 'bid_detail'),
    expect: () => [
      isA<PickupCodeRequestSending>(),
      isA<PickupCodeRequestFailure>().having(
        (s) => s.error.code,
        'code',
        'code-still-valid',
      ),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.pickupCodeRequested,
        properties: {'source': 'bid_detail', 'outcome': 'error'},
      ),
    ).called(1),
  );

  blocTest<PickupCodeRequestCubit, PickupCodeRequestState>(
    'pendant l\'envoi, un second appui ne relance rien',
    build: () {
      stub(
        () => Future.delayed(
          const Duration(milliseconds: 20),
          () => (requestedAt: null, nextRequestAllowedAt: null),
        ),
      );
      return PickupCodeRequestCubit(repository, analytics);
    },
    act: (cubit) async {
      final first = cubit.request('bid-1', source: 'scan_confirm');
      await cubit.request('bid-1', source: 'scan_confirm');
      await first;
    },
    expect: () => [
      isA<PickupCodeRequestSending>(),
      isA<PickupCodeRequestSent>(),
    ],
    verify: (_) => verify(() => repository.requestNewCode('bid-1')).called(1),
  );

  group('PickupCodeRequestTooSoon.minutesLeft', () {
    final now = DateTime.utc(2026, 10, 9, 10);

    test('arrondit à la minute supérieure', () {
      final s = PickupCodeRequestTooSoon(
        now.add(const Duration(minutes: 9, seconds: 1)),
      );
      expect(s.minutesLeft(now), 10);
    });

    test('minute pile', () {
      final s = PickupCodeRequestTooSoon(now.add(const Duration(minutes: 3)));
      expect(s.minutesLeft(now), 3);
    });

    test('échéance passée : au moins 1', () {
      final s = PickupCodeRequestTooSoon(
        now.subtract(const Duration(seconds: 5)),
      );
      expect(s.minutesLeft(now), 1);
    });

    test('échéance inconnue : null', () {
      expect(const PickupCodeRequestTooSoon(null).minutesLeft(now), isNull);
    });
  });
}
