import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:equatable/equatable.dart';

/// Action qui a produit le fil chargé.
///
/// L'écran a besoin de distinguer « je viens d'arriver » de « je viens
/// d'accepter » pour naviguer, sans multiplier les états et perdre le fil.
enum BidNegotiationAction {
  fetched,
  proposed,
  countered,
  accepted,
  rejected,
  cancelled,
}

sealed class BidNegotiationState extends Equatable {
  const BidNegotiationState();

  @override
  List<Object?> get props => [];
}

class BidNegotiationInitial extends BidNegotiationState {
  const BidNegotiationInitial();
}

class BidNegotiationLoading extends BidNegotiationState {
  const BidNegotiationLoading();
}

class BidNegotiationLoaded extends BidNegotiationState {
  final BidNegotiation negotiation;
  final BidNegotiationAction action;

  const BidNegotiationLoaded(
    this.negotiation, {
    this.action = BidNegotiationAction.fetched,
  });

  @override
  List<Object?> get props => [negotiation, action];
}

/// Le checkout de l'accord est prêt : l'écran enchaîne sur le parcours de
/// paiement carte existant (`PaymentBloc` → `DonyPaymentSheet`).
///
/// Le fil est porté avec, pour que l'écran continue d'afficher le colis et les
/// échanges pendant que la feuille de paiement s'ouvre par-dessus.
class BidNegotiationCheckoutReady extends BidNegotiationState {
  final BidCheckoutResponseModel checkout;
  final BidNegotiation? negotiation;

  const BidNegotiationCheckoutReady(this.checkout, {this.negotiation});

  @override
  List<Object?> get props => [checkout, negotiation];
}

class BidNegotiationError extends BidNegotiationState {
  final AppException error;

  /// Dernier fil connu, conservé pour que l'écran reste affichable derrière
  /// le message d'erreur plutôt que de retomber sur un écran vide.
  final BidNegotiation? negotiation;

  const BidNegotiationError(this.error, {this.negotiation});

  @override
  List<Object?> get props => [error, negotiation];
}
