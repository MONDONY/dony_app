part of 'notification_prefs_bloc.dart';

class NotificationPrefsState extends Equatable {
  final Map<String, bool> prefs;

  /// Cloche « me prévenir des nouveaux colis compatibles » (réglage serveur).
  /// `null` tant que la valeur n'a pas été lue, ou si la lecture a échoué : la
  /// ligne est alors désactivée plutôt que d'afficher un état inventé.
  final bool? packageMatchAlert;

  /// Lecture serveur des préférences en cours.
  final bool isSyncing;

  /// Message affiché quand l'écriture serveur a échoué et que la bascule a été
  /// annulée. `null` dès qu'une nouvelle bascule repart.
  final String? errorMessage;

  const NotificationPrefsState({
    required this.prefs,
    this.packageMatchAlert,
    this.isSyncing = false,
    this.errorMessage,
  });

  NotificationPrefsState copyWith({
    Map<String, bool>? prefs,
    bool? packageMatchAlert,
    bool? isSyncing,
    String? Function()? errorMessageGetter,
  }) => NotificationPrefsState(
    prefs: prefs ?? this.prefs,
    packageMatchAlert: packageMatchAlert ?? this.packageMatchAlert,
    isSyncing: isSyncing ?? this.isSyncing,
    errorMessage: errorMessageGetter != null
        ? errorMessageGetter()
        : errorMessage,
  );

  @override
  List<Object?> get props => [
    prefs,
    packageMatchAlert,
    isSyncing,
    errorMessage,
  ];
}
