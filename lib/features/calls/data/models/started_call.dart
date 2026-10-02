/// Appel créé et mis en sonnerie par le back (`POST /conversations/{id}/calls`).
class StartedCall {
  const StartedCall({required this.callId, required this.callType});

  final String callId;
  final String callType;

  factory StartedCall.fromJson(Map<String, dynamic> json) => StartedCall(
    callId: json['callId'] as String,
    callType: (json['callType'] as String?) ?? 'audio_call',
  );
}
