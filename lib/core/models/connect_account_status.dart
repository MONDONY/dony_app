class ConnectAccountStatus {
  final String? accountId;
  final String status;
  final String? country;
  final bool isProAccount;
  final String? reason;

  /// Stripe ouvre-t-il un compte connecté dans le pays de l'utilisateur ?
  ///
  /// yadony dessert plus de pays que Stripe n'en couvre : les zones XOF et
  /// XAF, les États-Unis et le Canada n'y ont pas droit. Ces voyageurs
  /// encaissent en espèces, et on ne leur propose pas d'activer la carte.
  ///
  /// Vaut `true` quand le serveur ne renvoie pas le champ : un backend
  /// antérieur ne doit pas masquer l'activation pour tout le monde.
  final bool connectAvailableInCountry;

  const ConnectAccountStatus({
    this.accountId,
    required this.status,
    this.country,
    this.isProAccount = false,
    this.reason,
    this.connectAvailableInCountry = true,
  });

  factory ConnectAccountStatus.fromJson(Map<String, dynamic> json) {
    return ConnectAccountStatus(
      accountId: json['stripeAccountId'] as String?,
      status: json['stripeAccountStatus'] as String? ?? 'NOT_CREATED',
      country: json['country'] as String?,
      isProAccount: json['isProAccount'] as bool? ?? false,
      reason: json['reason'] as String?,
      connectAvailableInCountry:
          json['connectAvailableInCountry'] as bool? ?? true,
    );
  }

  bool get isComplete => status == 'ONBOARDING_COMPLETE';
  bool get needsOnboarding =>
      status == 'NOT_CREATED' || status == 'PENDING_ONBOARDING';

  /// Inscription **commencée mais pas terminée** : un compte Stripe existe,
  /// il lui manque des informations.
  ///
  /// À distinguer de [needsOnboarding], qui couvre aussi `NOT_CREATED`, c'est
  /// à dire l'utilisateur qui n'a jamais rien entamé. Seul cet état-ci mérite
  /// qu'on propose de « reprendre » quelque chose.
  bool get isOnboardingIncomplete => status == 'PENDING_ONBOARDING';
  bool get isDisabled => status == 'DISABLED';
  bool get isRejected => status == 'REJECTED';
}
