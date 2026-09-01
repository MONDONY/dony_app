abstract class SubscriptionsEvent {
  const SubscriptionsEvent();
}

class LoadSubscriptions extends SubscriptionsEvent {
  const LoadSubscriptions();
}

class UnsubscribeTraveler extends SubscriptionsEvent {
  final String travelerId;
  const UnsubscribeTraveler(this.travelerId);
}

class ToggleSubscriptionPush extends SubscriptionsEvent {
  final String travelerId;
  final bool enabled;
  const ToggleSubscriptionPush(this.travelerId, this.enabled);
}

/// Retire l'indicateur « nouveau » de tous les abonnements d'un coup.
class MarkAllSubscriptionsSeen extends SubscriptionsEvent {
  const MarkAllSubscriptionsSeen();
}
