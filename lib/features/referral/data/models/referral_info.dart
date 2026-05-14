class ReferralInfo {
  const ReferralInfo({
    required this.code,
    required this.shareUrl,
    required this.totalInvited,
    required this.signedUp,
    required this.rewarded,
    required this.totalEarnedCents,
  });

  final String code;
  final String shareUrl;
  final int totalInvited;
  final int signedUp;
  final int rewarded;
  final int totalEarnedCents;

  factory ReferralInfo.fromJson(Map<String, dynamic> json) => ReferralInfo(
        code: json['code'] as String,
        shareUrl: json['shareUrl'] as String,
        totalInvited: json['totalInvited'] as int? ?? 0,
        signedUp: json['signedUp'] as int? ?? 0,
        rewarded: json['rewarded'] as int? ?? 0,
        totalEarnedCents: json['totalEarnedCents'] as int? ?? 0,
      );
}
