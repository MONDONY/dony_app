abstract class TravelerSubscribeEvent {
  const TravelerSubscribeEvent();
}

class LoadSubscribeStatus extends TravelerSubscribeEvent {
  final String travelerId;
  const LoadSubscribeStatus(this.travelerId);
}

class SubscribePressed extends TravelerSubscribeEvent {
  const SubscribePressed();
}

class UnsubscribePressed extends TravelerSubscribeEvent {
  const UnsubscribePressed();
}

class TogglePushPressed extends TravelerSubscribeEvent {
  final bool enabled;
  const TogglePushPressed(this.enabled);
}
