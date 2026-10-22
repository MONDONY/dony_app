import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tiny test that exercises every event const constructor so that
/// the coverage tool registers those lines as covered.
void main() {
  group('SubscriptionsEvent constructors', () {
    test('LoadSubscriptions is instantiable', () {
      const e = LoadSubscriptions();
      expect(e, isA<SubscriptionsEvent>());
    });

    test('UnsubscribeTraveler stores travelerId', () {
      const e = UnsubscribeTraveler('traveler-42');
      expect(e.travelerId, 'traveler-42');
    });

    test('ToggleSubscriptionPush stores fields', () {
      const e = ToggleSubscriptionPush('traveler-7', true);
      expect(e.travelerId, 'traveler-7');
      expect(e.enabled, isTrue);
    });
  });
}
