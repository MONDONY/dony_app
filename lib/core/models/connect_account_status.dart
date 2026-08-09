class ConnectAccountStatus {
  final String? accountId;
  final String status;
  final String? country;
  final bool isProAccount;
  final String? reason;

  /// Champs Stripe encore requis (ex. "external_account") — miroir non-PII
  /// de `account.requirements.currently_due`. Permet d'afficher précisément
  /// ce qu'il reste à fournir plutôt qu'un message générique.
  final Set<String> requirementsCurrentlyDue;

  const ConnectAccountStatus({
    this.accountId,
    required this.status,
    this.country,
    this.isProAccount = false,
    this.reason,
    this.requirementsCurrentlyDue = const {},
  });

  factory ConnectAccountStatus.fromJson(Map<String, dynamic> json) {
    return ConnectAccountStatus(
      accountId: json['stripeAccountId'] as String?,
      status: json['stripeAccountStatus'] as String? ?? 'NOT_CREATED',
      country: json['country'] as String?,
      isProAccount: json['isProAccount'] as bool? ?? false,
      reason: json['reason'] as String?,
      requirementsCurrentlyDue: (json['requirementsCurrentlyDue'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
    );
  }

  bool get isComplete => status == 'ONBOARDING_COMPLETE';
  bool get needsOnboarding =>
      status == 'NOT_CREATED' || status == 'PENDING_ONBOARDING';
  bool get isDisabled => status == 'DISABLED';
  bool get isRejected => status == 'REJECTED';
}
