abstract class ProfilePublicEvent {
  const ProfilePublicEvent();
}

class ProfilePublicRequested extends ProfilePublicEvent {
  const ProfilePublicRequested(this.userId);

  final String userId;
}
