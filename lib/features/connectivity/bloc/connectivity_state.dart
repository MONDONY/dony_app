import 'package:equatable/equatable.dart';

enum ConnectivityStatus { online, weak, offline }

class ConnectivityState extends Equatable {
  const ConnectivityState({
    this.status = ConnectivityStatus.online,
    this.justReconnected = false,
  });

  final ConnectivityStatus status;

  /// true juste après un retour à [ConnectivityStatus.online] depuis weak ou
  /// offline — pilote le bandeau vert de confirmation ("Connexion rétablie"),
  /// qui s'auto-masque ensuite. Sans ce flag transitoire, le bandeau
  /// disparaîtrait en silence dès le retour du réseau, laissant l'utilisateur
  /// deviner si tout est vraiment rétabli.
  final bool justReconnected;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    bool? justReconnected,
  }) => ConnectivityState(
    status: status ?? this.status,
    justReconnected: justReconnected ?? this.justReconnected,
  );

  @override
  List<Object?> get props => [status, justReconnected];
}
