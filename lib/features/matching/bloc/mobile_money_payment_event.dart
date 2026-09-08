import 'package:equatable/equatable.dart';

sealed class MobileMoneyPaymentEvent extends Equatable {
  const MobileMoneyPaymentEvent();

  @override
  List<Object?> get props => [];
}

/// Ouverture de l'écran d'attente : lit le statut courant du bid ; sans
/// dépôt vivant ni séquestre déjà atteint, lance l'initiation d'un premier
/// dépôt.
class MobileMoneyPaymentOpened extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentOpened({required this.bidId});
  final String bidId;

  @override
  List<Object?> get props => [bidId];
}

/// Nouvel essai de dépôt, déclenché par l'utilisateur (lien expiré, dépôt
/// refusé), éventuellement avec un autre numéro payeur.
class MobileMoneyPaymentInitiateRequested extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentInitiateRequested({
    required this.bidId,
    this.phoneNumber,
  });
  final String bidId;
  final String? phoneNumber;

  @override
  List<Object?> get props => [bidId, phoneNumber];
}

/// Sondage périodique du statut : silencieux, ne passe jamais par Loading
/// pour éviter de faire clignoter l'écran pendant l'attente.
class MobileMoneyStatusPolled extends MobileMoneyPaymentEvent {
  const MobileMoneyStatusPolled({required this.bidId});
  final String bidId;

  @override
  List<Object?> get props => [bidId];
}
