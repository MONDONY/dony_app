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

/// Lit l'état serveur de la cloche « nouveaux colis compatibles ».
class NotifPackageMatchAlertLoadRequested extends NotificationPrefsEvent {
  const NotifPackageMatchAlertLoadRequested();
}

/// Bascule la cloche « nouveaux colis compatibles » (réglage serveur).
class NotifPackageMatchAlertToggled extends NotificationPrefsEvent {
  final bool enabled;
  const NotifPackageMatchAlertToggled(this.enabled);
  @override
  List<Object?> get props => [enabled];
}
