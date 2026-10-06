import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/recipient_replacement/recipient_replacement_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBidRepository extends Mock implements BidRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

BidModel _bid({DateTime? requestedAt}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'IN_TRANSIT',
  recipientDeclined: true,
  recipientReplacementRequestedAt: requestedAt,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// Erreur telle que la rend l'intercepteur : l'[AppException] typée dans
/// `error`, le ProblemDetail brut dans `response`.
DioException _httpError(
  int status,
  AppException mapped, [
  Map<String, dynamic>? body,
]) {
  final options = RequestOptions(
    path: '/bids/bid-1/recipient/replacement-request',
  );
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
  late MockBidRepository repository;
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockBidRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  void stubRequest(Future<BidModel> Function() answer) {
    when(
      () => repository.requestRecipientReplacement(any()),
    ).thenAnswer((_) => answer());
  }

  blocTest<RecipientReplacementCubit, RecipientReplacementState>(
    'succès : bid à jour, analytics sans identité',
    build: () {
      stubRequest(
        () async => _bid(requestedAt: DateTime.utc(2026, 10, 6, 8, 30)),
      );
      return RecipientReplacementCubit(repository, analytics);
    },
    act: (cubit) => cubit.request(_bid()),
    expect: () => [
      isA<RecipientReplacementSubmitting>(),
      isA<RecipientReplacementSent>().having(
        (s) => s.bid.recipientReplacementRequestedAt,
        'requestedAt',
        DateTime.utc(2026, 10, 6, 8, 30),
      ),
    ],
    verify: (_) {
      verify(() => repository.requestRecipientReplacement('bid-1')).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.recipientReplacementRequested,
          properties: {'status': 'IN_TRANSIT', 'outcome': 'sent'},
        ),
      ).called(1);
    },
  );

  blocTest<RecipientReplacementCubit, RecipientReplacementState>(
    '429 : lit nextRequestAllowedAt du ProblemDetail',
    build: () {
      stubRequest(
        () async => throw _httpError(429, const RateLimitException(), {
          'code': 'recipient-replacement-too-soon',
          'nextRequestAllowedAt': '2026-10-06T20:30Z',
        }),
      );
      return RecipientReplacementCubit(repository, analytics);
    },
    act: (cubit) => cubit.request(_bid()),
    expect: () => [
      isA<RecipientReplacementSubmitting>(),
      isA<RecipientReplacementTooSoon>().having(
        (s) => s.nextRequestAllowedAt,
        'next',
        DateTime.utc(2026, 10, 6, 20, 30),
      ),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.recipientReplacementRequested,
        properties: {'status': 'IN_TRANSIT', 'outcome': 'too_soon'},
      ),
    ).called(1),
  );

  blocTest<RecipientReplacementCubit, RecipientReplacementState>(
    '429 sans date lisible : date inconnue',
    build: () {
      stubRequest(
        () async => throw _httpError(429, const RateLimitException(), {
          'nextRequestAllowedAt': 'pas une date',
        }),
      );
      return RecipientReplacementCubit(repository, analytics);
    },
    act: (cubit) => cubit.request(_bid()),
    expect: () => [
      isA<RecipientReplacementSubmitting>(),
      isA<RecipientReplacementTooSoon>().having(
        (s) => s.nextRequestAllowedAt,
        'next',
        isNull,
      ),
    ],
  );

  blocTest<RecipientReplacementCubit, RecipientReplacementState>(
    '429 sans corps : date inconnue',
    build: () {
      stubRequest(() async => throw const RateLimitException());
      return RecipientReplacementCubit(repository, analytics);
    },
    act: (cubit) => cubit.request(_bid()),
    expect: () => [
      isA<RecipientReplacementSubmitting>(),
      isA<RecipientReplacementTooSoon>().having(
        (s) => s.nextRequestAllowedAt,
        'next',
        isNull,
      ),
    ],
  );

  blocTest<RecipientReplacementCubit, RecipientReplacementState>(
    '409 recipient-not-declined : conflit avec le code',
    build: () {
      stubRequest(
        () async => throw _httpError(
          409,
          const ConflictException('x', code: 'recipient-not-declined'),
        ),
      );
      return RecipientReplacementCubit(repository, analytics);
    },
    act: (cubit) => cubit.request(_bid()),
    expect: () => [
      isA<RecipientReplacementSubmitting>(),
      isA<RecipientReplacementConflict>().having(
        (s) => s.code,
        'code',
        'recipient-not-declined',
      ),
    ],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  blocTest<RecipientReplacementCubit, RecipientReplacementState>(
    'erreur réseau : échec typé',
    build: () {
      stubRequest(
        () async => throw DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      return RecipientReplacementCubit(repository, analytics);
    },
    act: (cubit) => cubit.request(_bid()),
    expect: () => [
      isA<RecipientReplacementSubmitting>(),
      isA<RecipientReplacementFailure>().having(
        (s) => s.error,
        'error',
        isA<OfflineException>(),
      ),
    ],
  );

  blocTest<RecipientReplacementCubit, RecipientReplacementState>(
    'double tap pendant l\'envoi : un seul appel',
    build: () {
      stubRequest(() async => _bid());
      return RecipientReplacementCubit(repository, analytics);
    },
    act: (cubit) async {
      final first = cubit.request(_bid());
      await cubit.request(_bid());
      await first;
    },
    verify: (_) =>
        verify(() => repository.requestRecipientReplacement('bid-1')).called(1),
  );

  test('fermé pendant l\'envoi : aucun état émis après', () async {
    stubRequest(() async => _bid());
    final cubit = RecipientReplacementCubit(repository, analytics);
    final future = cubit.request(_bid());
    await cubit.close();
    await future;
    expect(cubit.state, isA<RecipientReplacementSubmitting>());
  });

  test('fermé pendant une erreur : aucun état émis après', () async {
    stubRequest(() async => throw const RateLimitException());
    final cubit = RecipientReplacementCubit(repository, analytics);
    final future = cubit.request(_bid());
    await cubit.close();
    await future;
    expect(cubit.state, isA<RecipientReplacementSubmitting>());
  });
}
