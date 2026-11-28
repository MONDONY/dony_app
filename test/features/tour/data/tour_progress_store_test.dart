import 'package:dony/features/tour/data/tour_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockBox box;
  final stored = <String, dynamic>{};

  setUp(() {
    stored.clear();
    box = _MockBox();
    when(
      () => box.get(any()),
    ).thenAnswer((inv) => stored[inv.positionalArguments.first as String]);
    when(() => box.put(any(), any())).thenAnswer((inv) async {
      stored[inv.positionalArguments[0] as String] = inv.positionalArguments[1];
    });
  });

  test('rien d\'écrit : rien de vu, aucune date', () {
    final store = TourProgressStore(box);
    expect(store.readSeen('uid-1'), 0);
    expect(store.readDoneAt('uid-1'), isNull);
    expect(store.readLastContextualDay('uid-1'), isNull);
  });

  test('les trois valeurs se relisent par compte', () async {
    final store = TourProgressStore(box);
    final at = DateTime(2026, 11, 28, 10);
    await store.writeSeen('uid-1', 5);
    await store.writeDoneAt('uid-1', at);
    await store.writeLastContextualDay('uid-1', '2026-11-28');

    expect(store.readSeen('uid-1'), 5);
    expect(store.readDoneAt('uid-1'), at);
    expect(store.readLastContextualDay('uid-1'), '2026-11-28');
    expect(store.readSeen('uid-2'), 0);
    expect(stored['${TourProgressStore.seenPrefix}uid-1'], 5);
  });

  test('une valeur illisible vaut « rien de vu »', () {
    stored['${TourProgressStore.seenPrefix}uid-1'] = 'oups';
    stored['${TourProgressStore.doneAtPrefix}uid-1'] = 'oups';
    stored['${TourProgressStore.lastContextualPrefix}uid-1'] = 12;
    final store = TourProgressStore(box);
    expect(store.readSeen('uid-1'), 0);
    expect(store.readDoneAt('uid-1'), isNull);
    expect(store.readLastContextualDay('uid-1'), isNull);
    stored['${TourProgressStore.seenPrefix}uid-1'] = -3;
    expect(store.readSeen('uid-1'), 0);
  });

  test(
    'un stockage qui plante ne casse ni la lecture ni l\'écriture',
    () async {
      when(() => box.get(any())).thenThrow(StateError('fermée'));
      when(() => box.put(any(), any())).thenThrow(StateError('fermée'));
      final store = TourProgressStore(box);
      expect(store.readSeen('uid-1'), 0);
      expect(store.readDoneAt('uid-1'), isNull);
      expect(store.readLastContextualDay('uid-1'), isNull);
      await store.writeSeen('uid-1', 1);
      await store.writeDoneAt('uid-1', DateTime(2026));
      await store.writeLastContextualDay('uid-1', 'x');
    },
  );
}
