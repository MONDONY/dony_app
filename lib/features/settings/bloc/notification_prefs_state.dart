part of 'notification_prefs_bloc.dart';

class NotificationPrefsState extends Equatable {
  final Map<String, bool> prefs;

  /// Cloche « me prévenir des nouveaux colis compatibles » (réglage serveur).
  /// `null` tant que la valeur n'a pas été lue, ou si la lecture a échoué : la
  /// ligne est alors désactivée plutôt que d'afficher un état inventé.
  final bool? packageMatchAlert;

  const NotificationPrefsState({
    required this.prefs,
    this.packageMatchAlert,
  });

  NotificationPrefsState copyWith({
    Map<String, bool>? prefs,
    bool? packageMatchAlert,
  }) =>
      NotificationPrefsState(
        prefs: prefs ?? this.prefs,
        packageMatchAlert: packageMatchAlert ?? this.packageMatchAlert,
      );

  @override
  List<Object?> get props => [prefs, packageMatchAlert];
}
