/// Jeton Stream Video de l'utilisateur, délivré par `GET /calls/token` (24 h).
class CallToken {
  const CallToken({
    required this.apiKey,
    required this.userId,
    required this.token,
    required this.expiresAt,
  });

  final String apiKey;
  final String userId;
  final String token;
  final DateTime expiresAt;

  factory CallToken.fromJson(Map<String, dynamic> json) => CallToken(
    apiKey: json['apiKey'] as String,
    userId: json['userId'] as String,
    token: json['token'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );
}
