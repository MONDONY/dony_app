import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_event.dart';
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

  group('TravelerHubEvent constructors', () {
    test('LoadTravelerHub stores travelerId', () {
      const e = LoadTravelerHub('hub-1');
      expect(e.travelerId, 'hub-1');
    });

    test('HubSubscribePressed is instantiable', () {
      const e = HubSubscribePressed();
      expect(e, isA<TravelerHubEvent>());
    });

    test('HubUnsubscribePressed is instantiable', () {
      const e = HubUnsubscribePressed();
      expect(e, isA<TravelerHubEvent>());
    });

    test('HubTogglePush stores enabled', () {
      const e = HubTogglePush(true);
      expect(e.enabled, isTrue);

      const f = HubTogglePush(false);
      expect(f.enabled, isFalse);
    });
  });
}
