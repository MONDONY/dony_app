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

/// Colis proposé quand la question porte sur l'un des siens sans dire lequel
/// (yadony-back `feature/assistant-colis`). Le back ne propose que les colis
/// dont l'utilisateur est l'expéditeur, le voyageur ou le destinataire.
class AssistantParcelChoice extends Equatable {
  const AssistantParcelChoice({
    required this.parcelId,
    required this.status,
    required this.role,
    required this.active,
    this.trackingNumber,
    this.departureCity,
    this.arrivalCity,
  });

  /// Lève une `TypeError` si l'identifiant, le statut ou le rôle manque :
  /// [AssistantAnswer] écarte alors ce colis sans rejeter la réponse.
  factory AssistantParcelChoice.fromJson(Map<String, dynamic> json) =>
      AssistantParcelChoice(
        parcelId: json['parcelId'] as String,
        status: json['status'] as String,
        role: json['role'] as String,
        active: json['active'] as bool? ?? false,
        trackingNumber: json['trackingNumber'] as String?,
        departureCity: json['departureCity'] as String?,
        arrivalCity: json['arrivalCity'] as String?,
      );

  final String parcelId;

  /// Nom du `BidStatus` du back (`IN_TRANSIT`, `COMPLETED`...).
  final String status;

  /// `SENDER`, `TRAVELER` ou `RECIPIENT`.
  final String role;

  /// En cours (ni livré, ni annulé, ni clos).
  final bool active;

  /// Absent quand le rôle ne le voit pas encore (voyageur avant la remise).
  final String? trackingNumber;
  final String? departureCity;
  final String? arrivalCity;

  @override
  List<Object?> get props => [
    parcelId,
    status,
    role,
    active,
    trackingNumber,
    departureCity,
    arrivalCity,
  ];
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
    this.parcelId,
    this.parcels = const [],
  });

  /// Lève une `TypeError` sur une réponse malformée (texte absent, `actions`
  /// qui n'est pas une liste, etc.) et une `FormatException` sur un texte vide
  /// ou blanc (jamais de bulle vide) : le dépôt les convertit en
  /// `AssistantNetworkException`.
  factory AssistantAnswer.fromJson(Map<String, dynamic> json) {
    final answer = json['answer'] as String;
    if (answer.trim().isEmpty) {
      throw const FormatException('assistant: empty answer');
    }
    return AssistantAnswer(
      answer: answer,
      answered: json['answered'] as bool? ?? false,
      actions: _parseActions(json['actions']),
      provider: json['provider'] as String? ?? 'none',
      remainingToday: (json['remainingToday'] as num?)?.toInt() ?? 0,
      parcelId: json['parcelId'] as String?,
      parcels: _parseParcels(json['parcels']),
    );
  }

  /// Absent d'un back antérieur : aucun choix. Un colis incomplet est écarté
  /// sans rejeter les autres.
  static List<AssistantParcelChoice> _parseParcels(Object? raw) {
    if (raw is! List) return const [];
    final parcels = <AssistantParcelChoice>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      try {
        parcels.add(AssistantParcelChoice.fromJson(item));
      } on TypeError {
        continue;
      }
    }
    return parcels;
  }

  /// Ignore les actions incomplètes (route ou libellé absent, non textuel ou
  /// vide) sans rejeter les autres ni le texte de la réponse.
  static List<AssistantAction> _parseActions(Object? raw) {
    if (raw == null) return const [];
    final list = raw as List<dynamic>;
    final actions = <AssistantAction>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final route = item['route'];
      final label = item['label'];
      if (route is! String || label is! String) continue;
      if (route.trim().isEmpty || label.trim().isEmpty) continue;
      actions.add(AssistantAction.fromJson(item));
    }
    return actions;
  }

  final String answer;
  final bool answered;
  final List<AssistantAction> actions;
  final String provider;
  final int remainingToday;

  /// Colis dont parle la réponse : renvoyé avec les questions suivantes.
  final String? parcelId;

  /// Colis à choisir ; vide hors de ce cas.
  final List<AssistantParcelChoice> parcels;

  @override
  List<Object?> get props => [
    answer,
    answered,
    actions,
    provider,
    remainingToday,
    parcelId,
    parcels,
  ];
}

/// Explication d'un écran, lue dans une fiche du back (`GET /assistant/screen`),
/// sans fournisseur d'IA ni quota.
class AssistantScreenIntro extends Equatable {
  const AssistantScreenIntro({
    required this.explanation,
    this.questions = const [],
    this.actions = const [],
  });

  /// Lève une `TypeError` ou une `FormatException` sur une réponse malformée :
  /// le dépôt la traite comme « rien à expliquer ».
  factory AssistantScreenIntro.fromJson(Map<String, dynamic> json) {
    final explanation = json['explanation'] as String;
    if (explanation.trim().isEmpty) {
      throw const FormatException('assistant: empty explanation');
    }
    final questions = json['questions'];
    return AssistantScreenIntro(
      explanation: explanation,
      questions: questions is List
          ? [
              for (final q in questions)
                if (q is String && q.trim().isNotEmpty) q,
            ]
          : const [],
      actions: AssistantAnswer.fromJson({
        'answer': explanation,
        'actions': json['actions'],
      }).actions,
    );
  }

  final String explanation;
  final List<String> questions;
  final List<AssistantAction> actions;

  @override
  List<Object?> get props => [explanation, questions, actions];
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
