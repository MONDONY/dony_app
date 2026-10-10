/// Gravité d'un échec pour la remontée Sentry, décidée par l'erreur elle-même
/// quand elle seule sait si elle est attendue (refus de carte, FLUTTER-G5).
enum ReportSeverity {
  /// Échec normal du parcours, déjà expliqué à l'utilisateur : jamais
  /// remonté.
  expected,

  /// Remonté en niveau `warning` : à surveiller, pas un défaut avéré.
  warning,

  /// Remonté en niveau `error`.
  error,
}

/// Erreur qui déclare sa propre [ReportSeverity]. `ErrorReportingService` la
/// lit sans dépendre de la feature qui la lève.
abstract interface class SeverityAwareError {
  ReportSeverity get reportSeverity;
}
