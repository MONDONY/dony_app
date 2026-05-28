abstract class TravelerHubEvent {
  const TravelerHubEvent();
}

class LoadTravelerHub extends TravelerHubEvent {
  final String travelerId;
  const LoadTravelerHub(this.travelerId);
}

class HubSubscribePressed extends TravelerHubEvent {
  const HubSubscribePressed();
}

class HubUnsubscribePressed extends TravelerHubEvent {
  const HubUnsubscribePressed();
}

class HubTogglePush extends TravelerHubEvent {
  final bool enabled;
  const HubTogglePush(this.enabled);
}
