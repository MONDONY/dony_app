class BlockedUserModel {
  final String userId;
  final String displayName;
  final DateTime blockedAt;

  const BlockedUserModel({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
  });

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) =>
      BlockedUserModel(
        userId: json['userId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Utilisateur',
        blockedAt:
            DateTime.tryParse(json['blockedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
