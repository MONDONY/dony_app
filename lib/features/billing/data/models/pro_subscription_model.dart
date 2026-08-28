import 'package:equatable/equatable.dart';

/// Statut de l'abonnement PRO, tel que rendu par `GET /billing/subscription`.
///
/// [none] est une valeur légitime du serveur (« pas d'abonnement »), à ne pas
/// confondre avec [unknown] (« ce client ne connaît pas cette valeur »).
enum ProSubscriptionStatus {
  active,
  pastDue,
  legacyGrace,
  canceled,
  expired,
  none,
  unknown;

  static ProSubscriptionStatus fromWire(String? value) =>
      switch (value?.toUpperCase()) {
        'ACTIVE' => ProSubscriptionStatus.active,
        'PAST_DUE' => ProSubscriptionStatus.pastDue,
        'LEGACY_GRACE' => ProSubscriptionStatus.legacyGrace,
        'CANCELED' => ProSubscriptionStatus.canceled,
        'EXPIRED' => ProSubscriptionStatus.expired,
        'NONE' => ProSubscriptionStatus.none,
        _ => ProSubscriptionStatus.unknown,
      };
}

/// Origine de l'abonnement PRO. Nullable dans le modèle car nulle dans la
/// réponse serveur quand [ProSubscriptionStatus.none].
enum ProSubscriptionSource {
  stripe,
  adminGrant,
  legacyFree,
  unknown;

  static ProSubscriptionSource? fromWire(String? value) =>
      switch (value?.toUpperCase()) {
        null => null,
        'STRIPE' => ProSubscriptionSource.stripe,
        'ADMIN_GRANT' => ProSubscriptionSource.adminGrant,
        'LEGACY_FREE' => ProSubscriptionSource.legacyFree,
        _ => ProSubscriptionSource.unknown,
      };
}

/// Abonnement PRO de l'utilisateur courant. Mappe la réponse de
/// `GET /billing/subscription`.
///
/// [active] est calculé côté serveur : il ne se redérive jamais du [status]
/// (un abonnement [ProSubscriptionStatus.pastDue] peut rester [active] tant
/// que la période de grâce n'est pas expirée).
class ProSubscriptionModel extends Equatable {
  const ProSubscriptionModel({
    required this.active,
    required this.status,
    required this.source,
    required this.billingCycle,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    required this.graceExpiresAt,
  });

  final bool active;
  final ProSubscriptionStatus status;
  final ProSubscriptionSource? source;
  final String? billingCycle;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime? graceExpiresAt;

  factory ProSubscriptionModel.fromJson(Map<String, dynamic> json) =>
      ProSubscriptionModel(
        // Repli sur `false` si la clé est absente ou nulle (réponse
        // dégradée) : mieux vaut taire le bandeau PRO qu'affirmer un état
        // non prouvé par le serveur.
        active: json['active'] as bool? ?? false,
        status: ProSubscriptionStatus.fromWire(json['status'] as String?),
        source: ProSubscriptionSource.fromWire(json['source'] as String?),
        billingCycle: json['billingCycle'] as String?,
        currentPeriodEnd: json['currentPeriodEnd'] != null
            ? DateTime.parse(json['currentPeriodEnd'] as String)
            : null,
        cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
        graceExpiresAt: json['graceExpiresAt'] != null
            ? DateTime.parse(json['graceExpiresAt'] as String)
            : null,
      );

  @override
  List<Object?> get props => [
    active,
    status,
    source,
    billingCycle,
    currentPeriodEnd,
    cancelAtPeriodEnd,
    graceExpiresAt,
  ];
}
