import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidAmendmentRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _bid = BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _a = BidAmendment(
  id: 'am-1',
  status: BidAmendmentStatus.proposed,
  rail: 'CASH',
  grossAmount: 26.8,
);

const _closed = BidAmendment(
  id: 'am-1',
  status: BidAmendmentStatus.cancelled,
  rail: 'CASH',
  grossAmount: 26.8,
);

void main() {
  late _MockRepository repository;
  late _MockAnalytics analytics;
  late AmendmentActionCubit cubit;

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = AmendmentActionCubit(repository, analytics);
  });

  tearDown(() => cubit.close());

  test('viewed_logsOnce', () {
    cubit
      ..viewed(isSender: true, status: BidAmendmentStatus.proposed)
      ..viewed(isSender: true, status: BidAmendmentStatus.proposed);

    verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidAmendmentViewed,
        properties: {'role': 'sender', 'status': 'PROPOSED'},
      ),
    ).called(1);
  });

  test('cancel_emitsDone_logsCancelled', () async {
    when(
      () => repository.cancel('bid-1', 'am-1'),
    ).thenAnswer((_) async => _closed);
    final seen = <AmendmentActionStatus>[];
    cubit.stream.listen((s) => seen.add(s.status));

    await cubit.cancel(_bid, _a);
    await Future<void>.delayed(Duration.zero);

    expect(seen, [AmendmentActionStatus.busy, AmendmentActionStatus.done]);
    verify(
      () => analytics.logEvent(AnalyticsEvents.bidAmendmentCancelled),
    ).called(1);
  });

  test('decline_emitsDone_logsDeclinedWithMethod', () async {
    when(
      () => repository.decline('bid-1', 'am-1'),
    ).thenAnswer((_) async => _closed);

    await cubit.decline(_bid, _a);

    expect(cubit.state.status, AmendmentActionStatus.done);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidAmendmentDeclined,
        properties: {'method': 'cash'},
      ),
    ).called(1);
  });

  test('notBrought_confirmThenCalls', () async {
    when(
      () => repository.notBrought('bid-1', 'am-1'),
    ).thenAnswer((_) async => _closed);

    await cubit.notBrought(_bid, _a);

    expect(cubit.state.status, AmendmentActionStatus.done);
    verify(() => repository.notBrought('bid-1', 'am-1')).called(1);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidAmendmentNotBrought,
        properties: {'method': 'cash'},
      ),
    ).called(1);
  });

  test('cancel_failure_emitsFailure_logsActionFailed', () async {
    when(() => repository.cancel('bid-1', 'am-1')).thenThrow(
      const ConflictException('x', code: 'amendment-not-cancellable'),
    );

    await cubit.cancel(_bid, _a);

    expect(cubit.state.status, AmendmentActionStatus.failure);
    expect(cubit.state.error?.code, 'amendment-not-cancellable');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidAmendmentActionFailed,
        properties: {
          'action': 'cancel',
          'error_code': 'amendment-not-cancellable',
        },
      ),
    ).called(1);
  });

  // Sheet fermé pendant l'appel : le cubit est fermé avec la route, mais
  // l'action confirmée par le serveur reste mesurée (et l'échec aussi).
  test('cancel_cubitClosedDuringCall_stillLogsCancelled', () async {
    final pending = Completer<BidAmendment>();
    when(
      () => repository.cancel('bid-1', 'am-1'),
    ).thenAnswer((_) => pending.future);

    final call = cubit.cancel(_bid, _a);
    await cubit.close();
    pending.complete(_closed);
    await call;

    verify(
      () => analytics.logEvent(AnalyticsEvents.bidAmendmentCancelled),
    ).called(1);
  });

  test('cancel_cubitClosedDuringCall_stillLogsFailure', () async {
    final pending = Completer<BidAmendment>();
    when(
      () => repository.cancel('bid-1', 'am-1'),
    ).thenAnswer((_) => pending.future);

    final call = cubit.cancel(_bid, _a);
    await cubit.close();
    pending.completeError(
      const ConflictException('x', code: 'amendment-not-cancellable'),
    );
    await call;

    verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidAmendmentActionFailed,
        properties: {
          'action': 'cancel',
          'error_code': 'amendment-not-cancellable',
        },
      ),
    ).called(1);
  });

  test('cancel_whileBusy_ignored', () async {
    when(() => repository.cancel('bid-1', 'am-1')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _closed;
    });

    final first = cubit.cancel(_bid, _a);
    await cubit.cancel(_bid, _a);
    await first;

    verify(() => repository.cancel('bid-1', 'am-1')).called(1);
  });
}
