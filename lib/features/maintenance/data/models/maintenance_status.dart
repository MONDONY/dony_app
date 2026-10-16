import 'package:equatable/equatable.dart';

/// Réponse de `GET /config/maintenance`.
class MaintenanceStatus extends Equatable {
  const MaintenanceStatus({
    required this.enabled,
    this.message,
    this.estimatedEndAt,
    this.exempt = false,
  });

  factory MaintenanceStatus.fromJson(Map<String, dynamic> json) {
    final end = json['estimatedEndAt'];
    return MaintenanceStatus(
      enabled: json['enabled'] == true,
      message: json['message'] as String?,
      estimatedEndAt: end is String ? DateTime.tryParse(end) : null,
      exempt: json['exempt'] == true,
    );
  }

  final bool enabled;

  /// Message saisi dans le back-office ; `null` = texte par défaut de l'app.
  final String? message;

  /// Heure de retour estimée (UTC), facultative.
  final DateTime? estimatedEndAt;

  /// Compte autorisé à utiliser l'app malgré la maintenance (testeur).
  final bool exempt;

  /// L'écran de maintenance doit-il recouvrir l'app pour ce compte ?
  bool get blocksApp => enabled && !exempt;

  @override
  List<Object?> get props => [enabled, message, estimatedEndAt, exempt];
}
