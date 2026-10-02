import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/data/activation_repository.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ActivationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  const status = ActivationStatus(
    intent: UserIntent.sender,
    firstActionDone: false,
  );

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  blocTest<ActivationCubit, ActivationState>(
    'charge le statut',
    build: () {
      when(() => repo.fetch()).thenAnswer((_) async => status);
      return ActivationCubit(repo, analytics);
    },
    act: (c) => c.load(),
    expect: () => [const ActivationLoading(), const ActivationLoaded(status)],
  );

  blocTest<ActivationCubit, ActivationState>(
    'ancien backend : indisponible',
    build: () {
      when(() => repo.fetch()).thenAnswer((_) async => null);
      return ActivationCubit(repo, analytics);
    },
    act: (c) => c.load(),
    expect: () => [const ActivationLoading(), const ActivationUnavailable()],
  );

  blocTest<ActivationCubit, ActivationState>(
    'erreur réseau',
    build: () {
      when(
        () => repo.fetch(),
      ).thenThrow(DioException(requestOptions: RequestOptions()));
      return ActivationCubit(repo, analytics);
    },
    act: (c) => c.load(),
    expect: () => [const ActivationLoading(), const ActivationError()],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.blocError,
        properties: {'bloc': 'ActivationCubit'},
      ),
    ).called(1),
  );

  blocTest<ActivationCubit, ActivationState>(
    'rafraîchissement silencieux quand déjà chargé',
    build: () {
      when(() => repo.fetch()).thenAnswer((_) async => status);
      return ActivationCubit(repo, analytics);
    },
    seed: () =>
        const ActivationLoaded(ActivationStatus(intent: UserIntent.traveler)),
    act: (c) => c.load(),
    expect: () => [const ActivationLoaded(status)],
  );

  blocTest<ActivationCubit, ActivationState>(
    'erreur pendant un rafraîchissement : garde le statut connu',
    build: () {
      when(
        () => repo.fetch(),
      ).thenThrow(DioException(requestOptions: RequestOptions()));
      return ActivationCubit(repo, analytics);
    },
    seed: () => const ActivationLoaded(status),
    act: (c) => c.load(),
    expect: () => <ActivationState>[],
  );

  blocTest<ActivationCubit, ActivationState>(
    'reset à la déconnexion',
    build: () => ActivationCubit(repo, analytics),
    seed: () => const ActivationLoaded(status),
    act: (c) => c.reset(),
    expect: () => [const ActivationInitial()],
  );
}
