import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/receptions/bloc/receptions_prompt_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/data/receptions_prompt_store.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ReceptionRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockBox extends Mock implements Box<dynamic> {}

class _MemoryStore implements ReceptionsPromptStore {
  final Set<String> ids = {};

  @override
  Set<String> dismissed() => ids;

  @override
  Future<void> dismiss(Iterable<String> bidIds) async => ids.addAll(bidIds);
}

const _pendingAwa = Reception(
  bidId: 'p1',
  linkStatus: 'PENDING',
  bidStatus: 'ACCEPTED',
  senderFirstName: 'Awa',
);
const _pending2 = Reception(
  bidId: 'p2',
  linkStatus: 'PENDING',
  bidStatus: 'ACCEPTED',
);
const _confirmed = Reception(
  bidId: 'c1',
  linkStatus: 'CONFIRMED',
  bidStatus: 'IN_TRANSIT',
);

/// YADONY-FLUTTER-PROD-12 : une destinataire tout juste inscrite ne voyait
/// pas son colis depuis l'accueil.
void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  late _MemoryStore store;

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    store = _MemoryStore();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  ReceptionsPromptCubit build() =>
      ReceptionsPromptCubit(repo, store, analytics);

  void stub(List<Reception> receptions) =>
      when(() => repo.getReceptions()).thenAnswer((_) async => receptions);

  test('un colis à confirmer : bandeau, prénom, route du colis', () async {
    stub([_pendingAwa, _confirmed]);
    final c = build();
    await c.loadFor('u1');

    final s = c.state as ReceptionsPromptVisible;
    expect(s.pending.map((r) => r.bidId), ['p1']);
    expect(s.senderFirstName, 'Awa');
    expect(s.route, '/receptions/p1');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.receptionsPromptShown,
        properties: {'count': 1},
      ),
    ).called(1);
  });

  test('plusieurs colis : Suivi sur Réceptions, pas de prénom', () async {
    stub([_pendingAwa, _pending2]);
    final c = build();
    await c.loadFor('u1');

    final s = c.state as ReceptionsPromptVisible;
    expect(s.senderFirstName, isNull);
    expect(s.route, kReceptionsSegmentRoute);
  });

  test('aucun colis à confirmer : rien', () async {
    stub([_confirmed]);
    final c = build();
    await c.loadFor('u1');
    expect(c.state, isA<ReceptionsPromptHidden>());
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
  });

  test('ancien back (404) : rien, sans erreur', () async {
    when(() => repo.getReceptions()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/receptions'),
        error: const NotFoundException(),
      ),
    );
    final c = build();
    await c.loadFor('u1');
    expect(c.state, isA<ReceptionsPromptHidden>());
  });

  test('une seule lecture par compte, relue pour un autre compte', () async {
    stub([_pendingAwa]);
    final c = build();
    await c.loadFor('u1');
    await c.loadFor('u1');
    verify(() => repo.getReceptions()).called(1);

    await c.loadFor(null);
    expect(c.state, isA<ReceptionsPromptHidden>());
    await c.loadFor('u2');
    verify(() => repo.getReceptions()).called(1);
    expect(c.state, isA<ReceptionsPromptVisible>());
  });

  test('toucher : route et receptions_prompt_tapped', () async {
    stub([_pendingAwa]);
    final c = build();
    expect(c.tap(), isNull);
    await c.loadFor('u1');

    expect(c.tap(), '/receptions/p1');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.receptionsPromptTapped,
        properties: {'count': 1},
      ),
    ).called(1);
  });

  test('fermer : masqué et mémorisé pour ces colis', () async {
    stub([_pendingAwa]);
    final c = build();
    await c.loadFor('u1');
    await c.dismiss();
    expect(c.state, isA<ReceptionsPromptHidden>());
    expect(store.ids, {'p1'});

    // Même colis au compte suivant : il ne revient pas ; un nouveau, si.
    stub([_pendingAwa, _pending2]);
    final again = build();
    await again.loadFor('u1');
    final s = again.state as ReceptionsPromptVisible;
    expect(s.pending.map((r) => r.bidId), ['p2']);
  });

  group('ReceptionsPromptStore', () {
    test('lit et ajoute les colis fermés', () async {
      final box = _MockBox();
      when(
        () => box.get(HiveService.kReceptionsPromptDismissed),
      ).thenReturn(['a', 3]);
      when(() => box.put(any(), any())).thenAnswer((_) async {});
      final s = ReceptionsPromptStore(() => box);

      expect(s.dismissed(), {'a'});
      await s.dismiss(['b']);
      verify(
        () => box.put(HiveService.kReceptionsPromptDismissed, ['a', 'b']),
      ).called(1);
    });

    test('stockage illisible : rien de fermé, aucune exception', () async {
      final s = ReceptionsPromptStore(() => throw StateError('box fermée'));
      expect(s.dismissed(), isEmpty);
      await s.dismiss(['b']);
    });
  });
}
