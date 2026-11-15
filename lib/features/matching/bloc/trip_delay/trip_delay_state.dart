import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:equatable/equatable.dart';

/// État de l'annonce d'un retard (`TripDelayCubit`).
sealed class TripDelayState extends Equatable {
  const TripDelayState();

  @override
  List<Object?> get props => const [];
}

/// Rien d'envoyé, ou nouvel essai possible après une erreur.
final class TripDelayInitial extends TripDelayState {
  const TripDelayInitial();
}

/// Annonce en cours d'envoi : le bouton tourne, la feuille ne se ferme pas.
final class TripDelayLoading extends TripDelayState {
  const TripDelayLoading();
}

/// Retard accepté par le serveur : les expéditeurs sont prévenus.
final class TripDelaySuccess extends TripDelayState {
  const TripDelaySuccess(this.delay);

  final TripDelayInfo delay;

  @override
  List<Object?> get props => [delay];
}

/// Annonce refusée ou impossible. [message] : texte du catalogue d'erreurs
/// (`detail` du serveur pour les codes qui le relaient), [code] : code métier
/// du back, `null` sans code.
final class TripDelayError extends TripDelayState {
  const TripDelayError(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}
