abstract class NotificationEvent {
  const NotificationEvent();
}

class NotificationsLoadRequested extends NotificationEvent {
  const NotificationsLoadRequested();
}

class NotificationMarkReadRequested extends NotificationEvent {
  final String id;
  const NotificationMarkReadRequested(this.id);
}

class NotificationsMarkAllReadRequested extends NotificationEvent {
  const NotificationsMarkAllReadRequested();
}

class NotificationDeleteRequested extends NotificationEvent {
  final String id;
  const NotificationDeleteRequested(this.id);
}
