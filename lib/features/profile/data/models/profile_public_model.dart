class ProfilePublicModel {
  const ProfilePublicModel({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.kycVerified,
    required this.isProAccount,
    required this.isKiloPro,
    required this.completedBidsCount,
    required this.averageRating,
    required this.ratingCount,
    required this.memberSince,
    required this.badges,
    this.contactMode,
    this.responseDelayHours,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool kycVerified;
  final bool isProAccount;
  final bool isKiloPro;
  final int completedBidsCount;
  final double averageRating;
  final int ratingCount;
  final String memberSince;
  final List<String> badges;
  final String? contactMode;
  final int? responseDelayHours;

  factory ProfilePublicModel.fromJson(Map<String, dynamic> json) {
    return ProfilePublicModel(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      kycVerified: json['kycVerified'] as bool? ?? false,
      isProAccount: json['isProAccount'] as bool? ?? false,
      isKiloPro: json['isKiloPro'] as bool? ?? false,
      completedBidsCount: json['completedBidsCount'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      memberSince: json['memberSince'] as String? ?? '',
      badges: (json['badges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      contactMode: json['contactMode'] as String?,
      responseDelayHours: json['responseDelayHours'] as int?,
    );
  }
}
