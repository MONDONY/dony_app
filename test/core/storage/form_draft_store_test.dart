import 'dart:convert';

import 'package:dony/core/storage/form_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/form_draft_test_doubles.dart';

void main() {
  late InMemoryFormDraftStorage storage;
  late DateTime now;
  late FormDraftStore store;

  setUp(() {
    storage = InMemoryFormDraftStorage();
    now = DateTime.utc(2026, 10, 13, 12);
    store = testFormDraftStore(storage: storage, clock: () => now);
  });

  test('save puis read rend la saisie et sa date', () async {
    expect(await store.save(FormDraftKind.trip, {'step': 1, 'a': 'b'}), isTrue);

    final draft = await store.read(FormDraftKind.trip);

    expect(draft, isNotNull);
    expect(draft!.data['a'], 'b');
    expect(draft.step, 1);
    expect(draft.savedAt, now);
  });

  test('un brouillon par formulaire et par compte', () async {
    await store.save(FormDraftKind.trip, {'step': 0});

    expect(await store.read(FormDraftKind.packageRequest), isNull);
    final other = testFormDraftStore(storage: storage, uid: 'autre');
    expect(await other.read(FormDraftKind.trip), isNull);
    expect(storage.values.keys.single, 'form_draft_trip_uid-test');
  });

  test('sans compte connecté : rien n\'est lu ni écrit', () async {
    final anonymous = testFormDraftStore(storage: storage, uid: null);

    expect(await anonymous.save(FormDraftKind.trip, {'step': 0}), isFalse);
    expect(await anonymous.read(FormDraftKind.trip), isNull);
    await anonymous.delete(FormDraftKind.trip);
    expect(storage.values, isEmpty);
    expect(
      await testFormDraftStore(
        storage: storage,
        uid: '',
      ).read(FormDraftKind.trip),
      isNull,
    );
  });

  test('step absent vaut 0', () async {
    await store.save(FormDraftKind.trip, {'x': 1});
    expect((await store.read(FormDraftKind.trip))!.step, 0);
  });

  test('brouillon de plus de 30 jours : effacé, non proposé', () async {
    await store.save(FormDraftKind.trip, {'step': 0});
    now = now.add(const Duration(days: 31));

    expect(await store.read(FormDraftKind.trip), isNull);
    expect(storage.values, isEmpty);
  });

  test('contenu illisible ou d\'un autre format : effacé', () async {
    storage.values['form_draft_trip_uid-test'] = 'pas du json';
    expect(await store.read(FormDraftKind.trip), isNull);

    storage.values['form_draft_trip_uid-test'] = jsonEncode({
      'v': 99,
      'savedAt': now.toIso8601String(),
      'data': {},
    });
    expect(await store.read(FormDraftKind.trip), isNull);
    expect(storage.values, isEmpty);

    storage.values['form_draft_trip_uid-test'] = jsonEncode({
      'v': 1,
      'savedAt': 'jamais',
      'data': {},
    });
    expect(await store.read(FormDraftKind.trip), isNull);
  });

  test('trousseau en panne : échecs avalés', () async {
    storage.failWrites = true;
    expect(await store.save(FormDraftKind.trip, {'step': 0}), isFalse);

    storage.failReads = true;
    expect(await store.read(FormDraftKind.trip), isNull);
  });

  test('delete efface le brouillon', () async {
    await store.save(FormDraftKind.packageRequest, {'step': 2});
    await store.delete(FormDraftKind.packageRequest);
    expect(await store.read(FormDraftKind.packageRequest), isNull);
  });

  test('SecureFormDraftStorage se construit sans trousseau injecté', () {
    expect(SecureFormDraftStorage(), isA<FormDraftStorage>());
  });
}
