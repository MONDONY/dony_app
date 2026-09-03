abstract class AnnouncementsInboxEvent {
  const AnnouncementsInboxEvent();
}

class AnnouncementsInboxLoadRequested extends AnnouncementsInboxEvent {
  const AnnouncementsInboxLoadRequested();
}

class AnnouncementsInboxMarkReadRequested extends AnnouncementsInboxEvent {
  final String id;
  const AnnouncementsInboxMarkReadRequested(this.id);
}
