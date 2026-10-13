import 'package:dony/features/ratings/data/rating_prompt_tracker.dart';
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

  test('un colis n\'est proposé automatiquement qu\'une fois', () async {
    final tracker = RatingPromptTracker(box);

    expect(await tracker.claim('bid-1'), isTrue);
    expect(await tracker.claim('bid-1'), isFalse);
    expect(stored[RatingPromptTracker.storageKey], ['bid-1']);
  });

  test('chaque colis a sa propre ouverture automatique', () async {
    final tracker = RatingPromptTracker(box);

    expect(await tracker.claim('bid-1'), isTrue);
    expect(await tracker.claim('bid-2'), isTrue);
    expect(await tracker.claim('bid-1'), isFalse);
  });

  test(
    'la mémoire survit à une nouvelle instance (relance de l\'app)',
    () async {
      expect(await RatingPromptTracker(box).claim('bid-1'), isTrue);
      expect(await RatingPromptTracker(box).claim('bid-1'), isFalse);
    },
  );

  test('liste bornée aux derniers colis, les plus anciens sortent', () async {
    stored[RatingPromptTracker.storageKey] = [
      for (var i = 0; i < RatingPromptTracker.maxEntries; i++) 'bid-$i',
    ];
    final tracker = RatingPromptTracker(box);

    expect(await tracker.claim('bid-new'), isTrue);
    final ids = stored[RatingPromptTracker.storageKey] as List<String>;
    expect(ids, hasLength(RatingPromptTracker.maxEntries));
    expect(ids.first, 'bid-1');
    expect(ids.last, 'bid-new');
    // Le plus ancien, sorti de la liste, pourrait être reproposé une fois.
    expect(await tracker.claim('bid-0'), isTrue);
  });

  test('valeur stockée inattendue : traitée comme une liste vide', () async {
    stored[RatingPromptTracker.storageKey] = 'corrompu';
    expect(await RatingPromptTracker(box).claim('bid-1'), isTrue);
  });

  test('stockage en échec : pas d\'ouverture automatique', () async {
    when(() => box.put(any(), any())).thenThrow(HiveError('disque plein'));
    expect(await RatingPromptTracker(box).claim('bid-1'), isFalse);
  });
}
