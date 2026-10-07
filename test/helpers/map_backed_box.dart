import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<dynamic> {}

/// Boîte Hive en mémoire : `get` / `put` / `delete` sur [stored].
Box<dynamic> mapBackedBox(Map<String, dynamic> stored) {
  final box = _MockBox();
  when(
    () => box.get(any()),
  ).thenAnswer((inv) => stored[inv.positionalArguments.first as String]);
  when(() => box.put(any(), any())).thenAnswer((inv) async {
    stored[inv.positionalArguments[0] as String] = inv.positionalArguments[1];
  });
  when(() => box.delete(any())).thenAnswer((inv) async {
    stored.remove(inv.positionalArguments.first as String);
  });
  return box;
}
