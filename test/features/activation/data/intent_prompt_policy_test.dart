import 'package:dony/features/activation/data/intent_prompt_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

void main() {
  late MockBox box;
  late Map<String, Object?> store;

  setUp(() {
    box = MockBox();
    store = {};
    when(
      () => box.get(any<dynamic>()),
    ).thenAnswer((i) => store[i.positionalArguments.first as String]);
    when(() => box.put(any<dynamic>(), any<dynamic>())).thenAnswer((i) async {
      store[i.positionalArguments[0] as String] = i.positionalArguments[1];
    });
  });

  test('premier affichage autorisé', () {
    expect(IntentPromptPolicy(box).shouldShow(DateTime(2026, 10, 2)), isTrue);
  });

  test('second affichage seulement 7 jours après, jamais un troisième', () {
    final policy = IntentPromptPolicy(box)..markShown(DateTime(2026, 10, 2));
    expect(policy.shouldShow(DateTime(2026, 10, 8, 23)), isFalse);
    expect(policy.shouldShow(DateTime(2026, 10, 9)), isTrue);
    policy.markShown(DateTime(2026, 10, 9));
    expect(policy.shouldShow(DateTime(2026, 12, 2)), isFalse);
  });

  test('date illisible : on réaffiche une fois', () {
    store['intent_prompt_count'] = 1;
    store['intent_prompt_last_at'] = 'pas une date';
    expect(IntentPromptPolicy(box).shouldShow(DateTime(2026, 10, 2)), isTrue);
  });
}
