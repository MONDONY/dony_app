/// Fréquence des notifications d'une alerte corridor.
///
/// Le compteur de nouveautés et l'écran des correspondances ne dépendent pas
/// de ce réglage : une alerte silencieuse continue de compter, elle ne pousse
/// simplement rien.
enum AlertNotifyMode {
  /// Push dès qu'un trajet ou un colis matche, digest quotidien en filet.
  instant,

  /// Uniquement le digest quotidien de 9 h.
  daily,

  /// Aucune notification.
  muted;

  String get wire => switch (this) {
    AlertNotifyMode.instant => 'INSTANT',
    AlertNotifyMode.daily => 'DAILY',
    AlertNotifyMode.muted => 'MUTED',
  };

  static AlertNotifyMode fromWire(String? value) => switch (value) {
    'DAILY' => AlertNotifyMode.daily,
    'MUTED' => AlertNotifyMode.muted,
    _ => AlertNotifyMode.instant,
  };

  String get label => switch (this) {
    AlertNotifyMode.instant => 'Instantanée',
    AlertNotifyMode.daily => 'Quotidienne',
    AlertNotifyMode.muted => 'Silencieuse',
  };

  /// Phrase courte pour le bandeau de l'écran des correspondances.
  String get description => switch (this) {
    AlertNotifyMode.instant => 'Push instantané, digest à 9 h',
    AlertNotifyMode.daily => 'Digest quotidien à 9 h',
    AlertNotifyMode.muted => 'Sans notification, compteur seulement',
  };
}
