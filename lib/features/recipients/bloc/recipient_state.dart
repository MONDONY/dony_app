part of 'recipient_bloc.dart';

enum RecipientStatus { initial, loading, success, error }

class RecipientState {
  const RecipientState({
    this.status = RecipientStatus.initial,
    this.recipients = const [],
    this.error,
  });

  final RecipientStatus status;
  final List<Recipient> recipients;
  final String? error;

  RecipientState copyWith({
    RecipientStatus? status,
    List<Recipient>? recipients,
    String? error,
  }) =>
      RecipientState(
        status: status ?? this.status,
        recipients: recipients ?? this.recipients,
        error: error,
      );
}
