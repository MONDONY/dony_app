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
