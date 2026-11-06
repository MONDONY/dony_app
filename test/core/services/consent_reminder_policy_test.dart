import 'package:dony/core/services/consent_reminder_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

/// Relance du consentement de mesure d'usage : 3 affichages au plus, 3 jours
/// entre deux.
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

  test('première relance : tout de suite', () {
    expect(
      ConsentReminderPolicy(box).shouldShow(DateTime(2026, 11, 6)),
      isTrue,
    );
  });

  test('trois relances au plus, trois jours entre chacune', () {
    final policy = ConsentReminderPolicy(box)..markShown(DateTime(2026, 11, 6));

    expect(policy.shouldShow(DateTime(2026, 11, 8, 23)), isFalse);
    expect(policy.shouldShow(DateTime(2026, 11, 9)), isTrue);
    policy.markShown(DateTime(2026, 11, 9));

    expect(policy.shouldShow(DateTime(2026, 11, 11)), isFalse);
    expect(policy.shouldShow(DateTime(2026, 11, 12)), isTrue);
    policy.markShown(DateTime(2026, 11, 12));

    expect(store['consent_reminder_count'], 3);
    expect(policy.shouldShow(DateTime(2027)), isFalse);
  });

  test('date illisible : on relance une fois', () {
    store['consent_reminder_count'] = 1;
    store['consent_reminder_last_at'] = 'pas une date';
    expect(
      ConsentReminderPolicy(box).shouldShow(DateTime(2026, 11, 6)),
      isTrue,
    );
  });

  test('constantes : 3 relances, 3 jours', () {
    expect(ConsentReminderPolicy.maxReminders, 3);
    expect(ConsentReminderPolicy.gap, const Duration(days: 3));
  });
}
