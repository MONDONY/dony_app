import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/data/repositories/dispute_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements DisputeRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

DisputeModel _dispute({String status = 'OPEN'}) => DisputeModel(
  id: 'd1',
  bidId: null,
  type: 'SENDER_NO_SHOW_CONTESTED',
  status: status,
  refundFrozen: status == 'OPEN',
  createdAt: DateTime(2026, 7, 12),
  myRole: 'SENDER',
  otherPartyName: 'Awa K.',
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  departureCountryCode: 'FR',
  arrivalCountryCode: 'CI',
  tripDate: DateTime(2026, 6, 20),
  weightKg: 5,
  resolutionType: null,
  resolvedAt: null,
  resolutionNote: null,
  guaranteeAmountCents: null,
  isBeneficiary: false,
);

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  blocTest<DisputeListBloc, DisputeListState>(
    'load → loading puis loaded, analytics disputes_opened tiré une fois',
    build: () {
      when(() => repo.getMyDisputes()).thenAnswer((_) async => [_dispute()]);
      return DisputeListBloc(repo, analytics);
    },
    act: (b) => b
      ..add(const DisputesLoadRequested())
      ..add(const DisputesLoadRequested()),
    expect: () => [
      const DisputeListLoading(),
      isA<DisputeListLoaded>(),
      const DisputeListLoading(),
      isA<DisputeListLoaded>(),
    ],
    verify: (_) {
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.disputesOpened,
          properties: {'count': 1},
        ),
      ).called(1);
    },
  );

  blocTest<DisputeListBloc, DisputeListState>(
    'erreur réseau → DisputeListError',
    build: () {
      when(() => repo.getMyDisputes()).thenThrow(
        DioException(requestOptions: RequestOptions(path: '/disputes/me')),
      );
      return DisputeListBloc(repo, analytics);
    },
    act: (b) => b.add(const DisputesLoadRequested()),
    expect: () => [const DisputeListLoading(), isA<DisputeListError>()],
  );
}
