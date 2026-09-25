import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';

enum SubscriptionsStatus { initial, loading, success, error }

class SubscriptionsState {
  final SubscriptionsStatus status;
  final List<SubscriptionItem> items;
  final Object? error;
  const SubscriptionsState({
    this.status = SubscriptionsStatus.initial,
    this.items = const [],
    this.error,
  });

  SubscriptionsState copyWith({
    SubscriptionsStatus? status,
    List<SubscriptionItem>? items,
    Object? error,
  }) => SubscriptionsState(
    status: status ?? this.status,
    items: items ?? this.items,
    error: error,
  );
}
