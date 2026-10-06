import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';

abstract class CancellationState {}

class CancellationInitial extends CancellationState {}

class CancellationLoading extends CancellationState {}

class CancellationSuccess extends CancellationState {
  final CancellationModel cancellation;
  CancellationSuccess(this.cancellation);
}

class RematchSuggestionsLoaded extends CancellationState {
  final List<RematchSuggestionModel> suggestions;
  RematchSuggestionsLoaded(this.suggestions);
}

class NoShowReported extends CancellationState {}

/// L'expéditeur a signalé l'absence du voyageur : le back annule et
/// rembourse aussitôt, sans délai de contestation (FLUTTER-E3). Sous-type de
/// [NoShowReported] pour que les écouteurs existants (refetch) continuent de
/// réagir ; seul le message diffère.
class TravelerNoShowReported extends NoShowReported {}

class NoShowContested extends CancellationState {}

class DeliveryNoShowReported extends CancellationState {}

class DeliveryNoShowContested extends CancellationState {}

/// L'expéditeur a confirmé son absence → le bid est annulé (l'écran rafraîchit).
class NoShowConfirmed extends CancellationState {}

/// Annulation après remise réussie (l'écran rafraîchit le bid via BidBloc).
class CancelledAfterHandover extends CancellationState {}

/// Le voyageur a confirmé la restitution du colis (code de retour valide).
class ReturnConfirmed extends CancellationState {
  final ReturnCodeModel result;
  ReturnConfirmed(this.result);
}

/// Le code de retour de l'expéditeur (+ état de la restitution) a été chargé.
class ReturnCodeLoaded extends CancellationState {
  final ReturnCodeModel result;
  ReturnCodeLoaded(this.result);
}

class CancellationError extends CancellationState {
  final AppException error;
  CancellationError(this.error);
}

/// L'expéditeur a gardé son colis sur le trajet reporté.
class RescheduleKept extends CancellationState {}

/// L'expéditeur s'est retiré après le report : remboursement en cours.
class RescheduleWithdrawn extends CancellationState {}
