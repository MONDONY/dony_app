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
}
