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

  test('rien d\'écrit : le tour commence à la première bulle', () {
    expect(TourProgressStore(box).read('uid-1'), 0);
  });

  test('l\'avancée se relit par compte', () async {
    final store = TourProgressStore(box);
    await store.write('uid-1', 2);
    expect(store.read('uid-1'), 2);
    expect(store.read('uid-2'), 0);
    expect(stored['${TourProgressStore.keyPrefix}uid-1'], 2);
  });

  test('une valeur illisible vaut le début', () {
    stored['${TourProgressStore.keyPrefix}uid-1'] = 'oups';
    expect(TourProgressStore(box).read('uid-1'), 0);
    stored['${TourProgressStore.keyPrefix}uid-1'] = -3;
    expect(TourProgressStore(box).read('uid-1'), 0);
  });

  test(
    'un stockage qui plante ne casse ni la lecture ni l\'écriture',
    () async {
      when(() => box.get(any())).thenThrow(StateError('fermée'));
      when(() => box.put(any(), any())).thenThrow(StateError('fermée'));
      final store = TourProgressStore(box);
      expect(store.read('uid-1'), 0);
      await store.write('uid-1', 1);
    },
  );
}
