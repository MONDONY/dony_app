enum TravelerSubscribeStatus { initial, loading, ready, error }

class TravelerSubscribeState {
  final TravelerSubscribeStatus status;
  final bool subscribed;
  final bool pushEnabled;
  final String? error;

  const TravelerSubscribeState({
    this.status = TravelerSubscribeStatus.initial,
    this.subscribed = false,
    this.pushEnabled = false,
    this.error,
  });

  TravelerSubscribeState copyWith({
    TravelerSubscribeStatus? status,
    bool? subscribed,
    bool? pushEnabled,
    String? error,
  }) =>
      TravelerSubscribeState(
        status: status ?? this.status,
        subscribed: subscribed ?? this.subscribed,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        error: error,
      );
}
