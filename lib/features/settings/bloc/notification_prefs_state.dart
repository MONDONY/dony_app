part of 'notification_prefs_bloc.dart';

class NotificationPrefsState extends Equatable {
  final Map<String, bool> prefs;
  const NotificationPrefsState({required this.prefs});
  @override
  List<Object?> get props => [prefs];
}
