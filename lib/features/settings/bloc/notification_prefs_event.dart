part of 'notification_prefs_bloc.dart';

abstract class NotificationPrefsEvent extends Equatable {
  const NotificationPrefsEvent();
  @override
  List<Object?> get props => [];
}

class NotifPrefToggled extends NotificationPrefsEvent {
  final String key;
  const NotifPrefToggled(this.key);
  @override
  List<Object?> get props => [key];
}
