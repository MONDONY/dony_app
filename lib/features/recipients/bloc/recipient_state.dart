part of 'recipient_bloc.dart';

enum RecipientStatus { initial, loading, success, error }

class RecipientState {
  const RecipientState({
    this.status = RecipientStatus.initial,
    this.recipients = const [],
    this.error,
    this.loaded = false,
  });

  final RecipientStatus status;
  final List<Recipient> recipients;
  final Object? error;

  /// La liste a été chargée au moins une fois depuis le serveur : avant, une
  /// liste vide ne prouve pas qu'un numéro est inconnu du carnet.
  final bool loaded;

  RecipientState copyWith({
    RecipientStatus? status,
    List<Recipient>? recipients,
    Object? error,
    bool? loaded,
  }) => RecipientState(
    status: status ?? this.status,
    recipients: recipients ?? this.recipients,
    error: error,
    loaded: loaded ?? this.loaded,
  );
}
