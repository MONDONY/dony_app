import 'package:dony/features/kyc/data/kyc_completion_tracker.dart';
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

  test(
    'premier appel accordé, les suivants refusés pour le même compte',
    () async {
      final tracker = KycCompletionTracker(box, currentUid: () => 'uid-1');

      expect(await tracker.claim(), isTrue);
      expect(await tracker.claim(), isFalse);
      expect(stored['${KycCompletionTracker.keyPrefix}uid-1'], isTrue);
    },
  );

  test('un autre compte sur le même appareil est compté à part', () async {
    var uid = 'uid-1';
    final tracker = KycCompletionTracker(box, currentUid: () => uid);

    expect(await tracker.claim(), isTrue);
    uid = 'uid-2';
    expect(await tracker.claim(), isTrue);
  });

  test('sans compte connecté, accordé sans rien écrire', () async {
    final tracker = KycCompletionTracker(box, currentUid: () => null);

    expect(await tracker.claim(), isTrue);
    verifyNever(() => box.put(any(), any()));
  });

  test('stockage illisible : accordé plutôt que perdu', () async {
    when(() => box.get(any())).thenThrow(HiveError('box fermée'));
    final tracker = KycCompletionTracker(box, currentUid: () => 'uid-1');

    expect(await tracker.claim(), isTrue);
  });
}
