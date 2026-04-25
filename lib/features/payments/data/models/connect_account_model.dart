class ConnectAccountModel {
  final String stripeAccountId;
  final bool stripeOnboarded;

  const ConnectAccountModel({
    required this.stripeAccountId,
    required this.stripeOnboarded,
  });

  factory ConnectAccountModel.fromJson(Map<String, dynamic> json) =>
      ConnectAccountModel(
        stripeAccountId: json['stripeAccountId'] as String,
        stripeOnboarded: json['stripeOnboarded'] as bool? ?? false,
      );
}
