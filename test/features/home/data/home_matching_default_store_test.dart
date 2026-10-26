import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/home/data/home_matching_default_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<dynamic> {}

/// Box Hive en mémoire : ce qui est écrit est relu par un nouveau magasin,
/// comme après un redémarrage de l'app.
_MockBox _memoryBox(Map<dynamic, dynamic> store) {
  final box = _MockBox();
  when(
    () => box.get(any(), defaultValue: any(named: 'defaultValue')),
  ).thenAnswer(
    (inv) => store.containsKey(inv.positionalArguments.first)
        ? store[inv.positionalArguments.first]
        : inv.namedArguments[#defaultValue],
  );
  when(() => box.put(any(), any())).thenAnswer((inv) async {
    store[inv.positionalArguments[0]] = inv.positionalArguments[1];
  });
  return box;
}

void main() {
  late Map<dynamic, dynamic> store;

  setUp(() => store = {});

  test('aucun refus enregistré : le filtre peut s\'activer d\'office', () {
    final sut = HomeMatchingDefaultStore(_memoryBox(store));

    expect(sut.optedOut, isFalse);
  });

  test('refus enregistré : relu par un nouveau magasin', () async {
    await HomeMatchingDefaultStore(_memoryBox(store)).setOptedOut(value: true);

    expect(store[HiveService.kHomeMatchingTripsOptedOut], isTrue);
    expect(HomeMatchingDefaultStore(_memoryBox(store)).optedOut, isTrue);
  });

  test('refus levé : le filtre peut de nouveau s\'activer d\'office', () async {
    final sut = HomeMatchingDefaultStore(_memoryBox(store));
    await sut.setOptedOut(value: true);

    await sut.setOptedOut(value: false);

    expect(sut.optedOut, isFalse);
  });
}
