part of 'payment_bloc.dart';

sealed class PaymentEvent extends Equatable {
  const PaymentEvent();
  @override
  List<Object?> get props => [];
}

/// Lance la création du compte Stripe puis génère le lien d'onboarding.
class PaymentConnectAccountRequested extends PaymentEvent {
  const PaymentConnectAccountRequested();
}

/// Vérifie le statut d'onboarding après retour de la WebView Stripe.
class PaymentOnboardingStatusChecked extends PaymentEvent {
  const PaymentOnboardingStatusChecked();
}

/// Initie le paiement escrow pour un bid accepté.
class PaymentInitiated extends PaymentEvent {
  final String bidId;
  const PaymentInitiated(this.bidId);
  @override
  List<Object?> get props => [bidId];
}

/// La feuille de paiement Stripe a été complétée avec succès.
class PaymentSheetCompleted extends PaymentEvent {
  const PaymentSheetCompleted();
}

/// La feuille de paiement Stripe a échoué ou a été annulée.
class PaymentFailed extends PaymentEvent {
  final String message;
  const PaymentFailed(this.message);
  @override
  List<Object?> get props => [message];
}
