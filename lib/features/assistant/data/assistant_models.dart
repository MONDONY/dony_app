import 'package:equatable/equatable.dart';

/// Lien d'action proposé avec une réponse : ouvre une route de l'app.
class AssistantAction extends Equatable {
  const AssistantAction({required this.route, required this.label});

  factory AssistantAction.fromJson(Map<String, dynamic> json) =>
      AssistantAction(
        route: json['route'] as String,
        label: json['label'] as String,
      );

  final String route;
  final String label;

  @override
  List<Object?> get props => [route, label];
}

/// Réponse de `POST /assistant/ask`. Le champ `sources` renvoyé par le back
/// est ignoré à dessein : l'app ne l'affiche pas.
class AssistantAnswer extends Equatable {
  const AssistantAnswer({
    required this.answer,
    required this.answered,
    required this.actions,
    required this.provider,
    required this.remainingToday,
  });

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) =>
      AssistantAnswer(
        answer: json['answer'] as String? ?? '',
        answered: json['answered'] as bool? ?? false,
        actions: (json['actions'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AssistantAction.fromJson)
            .toList(),
        provider: json['provider'] as String? ?? 'none',
        remainingToday: json['remainingToday'] as int? ?? 0,
      );

  final String answer;
  final bool answered;
  final List<AssistantAction> actions;
  final String provider;
  final int remainingToday;

  @override
  List<Object?> get props => [
    answer,
    answered,
    actions,
    provider,
    remainingToday,
  ];
}

/// Un tour de la conversation envoyé au back comme contexte.
class AssistantHistoryTurn extends Equatable {
  const AssistantHistoryTurn({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};

  @override
  List<Object?> get props => [role, text];
}

/// Échecs de l'assistant, typés pour que le BLoC choisisse le message.
sealed class AssistantException implements Exception {
  const AssistantException();
}

/// Assistant éteint, ou compte non éligible (invité, sans identifiant).
final class AssistantDisabledException extends AssistantException {
  const AssistantDisabledException();
}

/// Quota quotidien atteint (HTTP 429).
final class AssistantQuotaExceededException extends AssistantException {
  const AssistantQuotaExceededException();
}

/// Toute autre panne : réseau, serveur, réponse inattendue.
final class AssistantNetworkException extends AssistantException {
  const AssistantNetworkException();
}
