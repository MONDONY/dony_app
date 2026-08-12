import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';

enum TravelerHubStatus { initial, loading, success, error }

class TravelerHubState {
  final TravelerHubStatus status;
  final bool subscribed;
  final bool pushEnabled;
  final List<TravelerAnnouncement> announcements;
  final String? error;

  const TravelerHubState({
    this.status = TravelerHubStatus.initial,
    this.subscribed = false,
    this.pushEnabled = false,
    this.announcements = const [],
    this.error,
  });

  TravelerHubState copyWith({
    TravelerHubStatus? status,
    bool? subscribed,
    bool? pushEnabled,
    List<TravelerAnnouncement>? announcements,
    String? error,
  }) =>
      TravelerHubState(
        status: status ?? this.status,
        subscribed: subscribed ?? this.subscribed,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        announcements: announcements ?? this.announcements,
        error: error,
      );
}
