enum AcceptanceStatus { accepted, requires3ds, failed }

class AcceptanceResponse {
  final AcceptanceStatus status;
  final String? clientSecret;
  final String? paymentIntentId;
  final String? error;

  const AcceptanceResponse({
    required this.status,
    this.clientSecret,
    this.paymentIntentId,
    this.error,
  });

  factory AcceptanceResponse.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status'] as String) {
      'ACCEPTED' => AcceptanceStatus.accepted,
      'REQUIRES_3DS' => AcceptanceStatus.requires3ds,
      _ => AcceptanceStatus.failed,
    };
    return AcceptanceResponse(
      status: status,
      clientSecret: json['clientSecret'] as String?,
      paymentIntentId: json['paymentIntentId'] as String?,
      error: json['error'] as String?,
    );
  }
}

class ConfirmResponse {
  final bool accepted;
  final String? error;

  const ConfirmResponse({required this.accepted, this.error});

  factory ConfirmResponse.fromJson(Map<String, dynamic> json) =>
      ConfirmResponse(
        accepted: json['accepted'] as bool,
        error: json['error'] as String?,
      );
}
