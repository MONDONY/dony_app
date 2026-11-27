abstract class KycEvent {
  const KycEvent();
}

class KycSessionRequested extends KycEvent {
  const KycSessionRequested();
}

class KycStatusRefreshed extends KycEvent {
  const KycStatusRefreshed();
}

class KycReset extends KycEvent {
  const KycReset();
}

class KycSessionAbandoned extends KycEvent {
  const KycSessionAbandoned();
}

/// Raison donnée en quittant la vérification (réponse facultative).
class KycAbandonReasonSubmitted extends KycEvent {
  const KycAbandonReasonSubmitted(this.reason, {this.durationMs});
  final String reason;
  final int? durationMs;
}
