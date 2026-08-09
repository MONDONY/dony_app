class ConnectAccountModel {
  final String stripeAccountId;
  final bool stripeOnboarded;
  final Set<String> requirementsCurrentlyDue;

  const ConnectAccountModel({
    required this.stripeAccountId,
    required this.stripeOnboarded,
    this.requirementsCurrentlyDue = const {},
  });

  factory ConnectAccountModel.fromJson(Map<String, dynamic> json) =>
      ConnectAccountModel(
        stripeAccountId: json['stripeAccountId'] as String,
        stripeOnboarded: json['stripeAccountStatus'] == 'ONBOARDING_COMPLETE',
        requirementsCurrentlyDue:
            (json['requirementsCurrentlyDue'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toSet() ??
                const {},
      );
}
