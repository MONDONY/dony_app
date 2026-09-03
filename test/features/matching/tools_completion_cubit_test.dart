import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/tools_completion_cubit.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/data/repositories/tools_completion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class _MockToolsCompletionRepository extends Mock
    implements ToolsCompletionRepository {}

void main() {
  late _MockToolsCompletionRepository repository;
  late MockAnalyticsBackend backend;

  setUp(() {
    repository = _MockToolsCompletionRepository();
    backend = MockAnalyticsBackend();
  });

  const model = ToolsCompletionModel(
    tools: [
      ToolStatus(key: ToolKey.addresses, count: 2),
      ToolStatus(key: ToolKey.recipients, count: 0),
      ToolStatus(key: ToolKey.alerts, count: 0),
      ToolStatus(key: ToolKey.tripTemplates, count: 1),
      ToolStatus(key: ToolKey.priceGrid, count: 6),
    ],
  );

  blocTest<ToolsCompletionCubit, ToolsCompletionState>(
    'load → loading puis loaded, event avec ready/total',
    build: () {
      when(
        () => repository.getToolsCompletion(),
      ).thenAnswer((_) async => model);
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      return ToolsCompletionCubit(repository, analytics);
    },
    act: (c) => c.load(),
    expect: () => [
      const ToolsCompletionState.loading(),
      const ToolsCompletionState.loaded(model),
    ],
    verify: (_) {
      verify(
        () => backend.capture(
          AnalyticsEvents.activitesHubToolsCompletionLoaded,
          {'ready': 3, 'total': 5},
        ),
      ).called(1);
    },
  );

  blocTest<ToolsCompletionCubit, ToolsCompletionState>(
    'load → hidden sur erreur, sans event',
    build: () {
      when(
        () => repository.getToolsCompletion(),
      ).thenThrow(Exception('network'));
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      return ToolsCompletionCubit(repository, analytics);
    },
    act: (c) => c.load(),
    expect: () => [
      const ToolsCompletionState.loading(),
      const ToolsCompletionState.hidden(),
    ],
    verify: (_) => verifyNever(() => backend.capture(any(), any())),
  );

  const model2 = ToolsCompletionModel(
    tools: [
      ToolStatus(key: ToolKey.addresses, count: 2),
      ToolStatus(key: ToolKey.recipients, count: 4),
      ToolStatus(key: ToolKey.alerts, count: 0),
      ToolStatus(key: ToolKey.tripTemplates, count: 1),
      ToolStatus(key: ToolKey.priceGrid, count: 6),
    ],
  );

  blocTest<ToolsCompletionCubit, ToolsCompletionState>(
    'rechargement depuis loaded : pas de passage par loading',
    build: () {
      when(
        () => repository.getToolsCompletion(),
      ).thenAnswer((_) async => model2);
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      return ToolsCompletionCubit(repository, analytics);
    },
    seed: () => const ToolsCompletionState.loaded(model),
    act: (c) => c.load(),
    // Un loading intercalé viderait la carte et les 5 badges du hub le temps
    // de la requête : la carte clignoterait à chaque retour d'un outil.
    expect: () => [const ToolsCompletionState.loaded(model2)],
  );

  blocTest<ToolsCompletionCubit, ToolsCompletionState>(
    'rechargement depuis loaded en échec : hidden',
    build: () {
      when(
        () => repository.getToolsCompletion(),
      ).thenThrow(Exception('network'));
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      return ToolsCompletionCubit(repository, analytics);
    },
    seed: () => const ToolsCompletionState.loaded(model),
    act: (c) => c.load(),
    expect: () => [const ToolsCompletionState.hidden()],
  );

  test('loaded expose le modèle, hidden ne prétend rien', () {
    expect(const ToolsCompletionState.loaded(model).model, same(model));
    expect(const ToolsCompletionState.hidden().model, isNull);
  });
}
