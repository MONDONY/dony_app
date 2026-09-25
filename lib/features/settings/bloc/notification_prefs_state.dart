part of 'notification_prefs_bloc.dart';

class NotificationPrefsState extends Equatable {
  final Map<String, bool> prefs;

  /// Cloche « me prévenir des nouveaux colis compatibles » (réglage serveur).
  /// `null` tant que la valeur n'a pas été lue, ou si la lecture a échoué : la
  /// ligne est alors désactivée plutôt que d'afficher un état inventé.
  final bool? packageMatchAlert;

  /// Lecture serveur des préférences en cours.
  final bool isSyncing;

  /// L'écriture serveur a échoué et la bascule a été annulée. L'écran choisit
  /// lui-même le texte (`settingsSyncFailed`) : aucun message n'est gardé ici.
  /// Remis à `false` dès qu'une nouvelle bascule repart.
  final bool hasSyncError;

  const NotificationPrefsState({
    required this.prefs,
    this.packageMatchAlert,
    this.isSyncing = false,
    this.hasSyncError = false,
  });

  NotificationPrefsState copyWith({
    Map<String, bool>? prefs,
    bool? packageMatchAlert,
    bool? isSyncing,
    bool? hasSyncError,
  }) => NotificationPrefsState(
    prefs: prefs ?? this.prefs,
    packageMatchAlert: packageMatchAlert ?? this.packageMatchAlert,
    isSyncing: isSyncing ?? this.isSyncing,
    hasSyncError: hasSyncError ?? this.hasSyncError,
  );

  @override
  List<Object?> get props => [
    prefs,
    packageMatchAlert,
    isSyncing,
    hasSyncError,
  ];
}
