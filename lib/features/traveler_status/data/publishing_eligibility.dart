import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:equatable/equatable.dart';

/// Pourquoi un voyageur peut ou non créer un trajet maintenant
/// (`GET /travelers/me/publishing-eligibility`).
enum PublishingReason {
  /// Il peut publier.
  ok('OK'),

  /// Limite mensuelle atteinte et aucune réponse « particulier / GP Pro » :
  /// il doit répondre avant de continuer.
  statusRequired('STATUS_REQUIRED'),

  /// Limite mensuelle atteinte, particulier : plus de trajet ce mois-ci.
  limitReached('LIMIT_REACHED'),

  /// Limite mensuelle atteinte, demande GP Pro en cours d'examen.
  gpProPending('GP_PRO_PENDING');

  const PublishingReason(this.wire);

  /// Valeur échangée avec le back.
  final String wire;

  /// Lit la raison du back. Absente ou inconnue (ancien back, future raison) :
  /// [ok], jamais un blocage sur une valeur qu'on ne comprend pas.
  static PublishingReason fromWire(String? value) {
    for (final reason in values) {
      if (reason.wire == value) return reason;
    }
    return ok;
  }

  /// Raison portée par le code d'erreur 403 d'une publication refusée, ou
  /// `null` si le code n'est pas un blocage de publication.
  static PublishingReason? fromErrorCode(String? code) => switch (code) {
    'traveler-status-required' => statusRequired,
    'monthly-limit-reached' => limitReached,
    'gp-pro-pending' => gpProPending,
    _ => null,
  };
}

/// Droit de publier un trajet ce mois-ci, tel que le back le calcule.
///
/// Tolérant : tout champ absent ou illisible prend sa valeur neutre, et une
/// réponse vide autorise la publication (ancien back, contrat additif).
class PublishingEligibility extends Equatable {
  const PublishingEligibility({
    required this.allowed,
    required this.reason,
    this.limit,
    this.used = 0,
    this.resetsOn,
    this.travelerStatus,
  });

  factory PublishingEligibility.fromJson(Map<String, dynamic> json) {
    final reason = PublishingReason.fromWire(json['reason'] as String?);
    final limit = json['limit'];
    final used = json['used'];
    final resetsOn = json['resetsOn'];
    final status = json['travelerStatus'];
    return PublishingEligibility(
      // La raison fait foi : `allowed` n'est que sa conséquence.
      allowed: reason == PublishingReason.ok,
      reason: reason,
      limit: limit is num ? limit.toInt() : null,
      used: used is num ? used.toInt() : 0,
      resetsOn: resetsOn is String ? _parseDate(resetsOn) : null,
      travelerStatus: TravelerStatus.parse(status is String ? status : null),
    );
  }

  /// Blocage connu seulement par le code d'une publication refusée : pas de
  /// chiffre, la reprise est le 1er du mois suivant.
  factory PublishingEligibility.blockedBy(
    PublishingReason reason, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    return PublishingEligibility(
      allowed: false,
      reason: reason,
      resetsOn: DateTime(today.year, today.month + 1),
    );
  }

  /// Rien ne bloque.
  static const PublishingEligibility ok = PublishingEligibility(
    allowed: true,
    reason: PublishingReason.ok,
  );

  final bool allowed;
  final PublishingReason reason;

  /// Limite mensuelle de l'utilisateur, `null` si aucune.
  final int? limit;

  /// Trajets publiés ce mois-ci.
  final int used;

  /// Jour de reprise (premier jour du mois suivant), à minuit local.
  final DateTime? resetsOn;
  final TravelerStatus? travelerStatus;

  static DateTime? _parseDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  @override
  List<Object?> get props => [
    allowed,
    reason,
    limit,
    used,
    resetsOn,
    travelerStatus,
  ];
}
