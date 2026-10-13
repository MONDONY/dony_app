import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/form_draft_test_doubles.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late InMemoryFormDraftStorage storage;
  late FormDraftStore store;
  late _MockAnalytics analytics;
  late FormDraftCubit cubit;

  setUp(() {
    storage = InMemoryFormDraftStorage();
    store = testFormDraftStore(storage: storage);
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = FormDraftCubit(store, analytics, FormDraftKind.trip);
  });

  tearDown(() => cubit.close());

  test('save : écrit, trace la source et l\'étape', () async {
    final ok = await cubit.save({'step': 2}, source: FormDraftSource.appBar);

    expect(ok, isTrue);
    expect(cubit.state, FormDraftStatus.saved);
    expect((await store.read(FormDraftKind.trip))!.step, 2);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.formDraftSaved,
        properties: {'kind': 'trip', 'step': 2, 'source': 'app_bar'},
      ),
    ).called(1);
  });

  test('save en échec : rien de tracé, état inchangé', () async {
    storage.failWrites = true;

    final ok = await cubit.save({
      'step': 0,
    }, source: FormDraftSource.exitDialog);

    expect(ok, isFalse);
    expect(cubit.state, FormDraftStatus.idle);
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
  });

  test('discard : efface et trace', () async {
    await store.save(FormDraftKind.trip, {'step': 1});

    await cubit.discard(source: FormDraftSource.exitDialog);

    expect(await store.read(FormDraftKind.trip), isNull);
    expect(cubit.state, FormDraftStatus.discarded);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.formDraftDiscarded,
        properties: {'kind': 'trip', 'source': 'exit_dialog'},
      ),
    ).called(1);
  });

  test('clear : efface sans tracer', () async {
    await store.save(FormDraftKind.trip, {'step': 1});

    await cubit.clear();

    expect(await store.read(FormDraftKind.trip), isNull);
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
  });
}
