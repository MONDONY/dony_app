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
        // Vide plutôt qu'un nom de repli figé en français : l'affichage passe
        // désormais par `profileUserFallback` (blocked_users_screen.dart).
        displayName: json['displayName'] as String? ?? '',
        blockedAt:
            DateTime.tryParse(json['blockedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
