import 'package:equatable/equatable.dart';

class MaintenanceState extends Equatable {
  const MaintenanceState({
    this.active = false,
    this.message,
    this.estimatedEndAt,
    this.checking = false,
  });

  /// L'écran de maintenance recouvre l'application.
  final bool active;

  /// Message de l'administrateur ; `null` = texte par défaut traduit.
  final String? message;

  /// Heure de retour estimée (UTC).
  final DateTime? estimatedEndAt;

  /// Vérification lancée par « Réessayer » en cours.
  final bool checking;

  MaintenanceState copyWith({bool? checking}) => MaintenanceState(
    active: active,
    message: message,
    estimatedEndAt: estimatedEndAt,
    checking: checking ?? this.checking,
  );

  @override
  List<Object?> get props => [active, message, estimatedEndAt, checking];
}
