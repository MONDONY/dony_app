import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockCancellationRepo extends Mock implements CancellationRepository {}

final _fakeCancellation = CancellationModel(
  announcementId: 'ann1',
  affectedBidsCount: 1,
  reason: 'changed_mind',
  rematchSuggestions: [],
  cancelledAt: DateTime(2026, 1, 1),
);

void main() {
  late _MockCancellationRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockCancellationRepo();
    backend = MockAnalyticsBackend();
  });

  CancellationBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return CancellationBloc(repo, a);
  }

  test('cancellation_initiated fires with reason on CancellationTripRequested success', () async {
    when(() => repo.cancelTrip(announcementId: any(named: 'announcementId'), reason: any(named: 'reason')))
        .thenAnswer((_) async => _fakeCancellation);

    final bloc = makeBloc();
    bloc.add(CancellationTripRequested(announcementId: 'ann1', reason: 'changed_mind'));
    await bloc.stream.firstWhere((s) => s is CancellationSuccess);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.cancellationInitiated,
      {'reason': 'changed_mind'},
    )).called(1);
  });

  test('no_show_reported_by_sender fires on TravelerNoShowReportRequested success', () async {
    when(() => repo.reportTravelerNoShow(any())).thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(TravelerNoShowReportRequested('bid-1'));
    await bloc.stream.firstWhere((s) => s is NoShowReported);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(AnalyticsEvents.noShowReportedBySender, any()))
        .called(1);
  });

  test('no_show_reported_by_traveler fires on NoShowReportRequested success', () async {
    when(() => repo.reportNoShow(any())).thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(NoShowReportRequested('bid-1'));
    await bloc.stream.firstWhere((s) => s is NoShowReported);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(AnalyticsEvents.noShowReportedByTraveler, any()))
        .called(1);
  });

  test('delivery_no_show_reported_by_traveler fires on DeliveryNoShowReportRequested success', () async {
    when(() => repo.reportDeliveryNoShow(any())).thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(DeliveryNoShowReportRequested('bid-1'));
    await bloc.stream.firstWhere((s) => s is DeliveryNoShowReported);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(AnalyticsEvents.deliveryNoShowReportedByTraveler, any()))
        .called(1);
  });

  test('delivery_no_show_reported_by_sender fires on TravelerDeliveryNoShowReportRequested success', () async {
    when(() => repo.reportTravelerDeliveryNoShow(any())).thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(TravelerDeliveryNoShowReportRequested('bid-1'));
    await bloc.stream.firstWhere((s) => s is DeliveryNoShowReported);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(AnalyticsEvents.deliveryNoShowReportedBySender, any()))
        .called(1);
  });

  test('delivery_no_show_contested fires on DeliveryNoShowContestRequested success', () async {
    when(() => repo.contestDeliveryNoShow(any())).thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(DeliveryNoShowContestRequested('bid-1'));
    await bloc.stream.firstWhere((s) => s is DeliveryNoShowContested);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(AnalyticsEvents.deliveryNoShowContested, any()))
        .called(1);
  });

  test('no event when disabled', () async {
    when(() => repo.cancelTrip(announcementId: any(named: 'announcementId'), reason: any(named: 'reason')))
        .thenAnswer((_) async => _fakeCancellation);
    final bloc = makeBloc(enabled: false);
    bloc.add(CancellationTripRequested(announcementId: 'ann1', reason: 'changed_mind'));
    await bloc.stream.firstWhere((s) => s is CancellationSuccess);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
