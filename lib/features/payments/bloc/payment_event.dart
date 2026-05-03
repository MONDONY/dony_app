part of 'payment_bloc.dart';

sealed class PaymentEvent extends Equatable {
  const PaymentEvent();
  @override
  List<Object?> get props => [];
}

/// Initiate payment sheet for bid checkout flow.
/// Used when user completes the checkout and is ready to pay.
class BidCheckoutPaymentRequested extends PaymentEvent {
  final String clientSecret;
  final String publishableKey;
  final String bidId;

  const BidCheckoutPaymentRequested({
    required this.clientSecret,
    required this.publishableKey,
    required this.bidId,
  });

  @override
  List<Object?> get props => [clientSecret, publishableKey, bidId];
}

/// Lance la création du compte Stripe puis génère le lien d'onboarding.
class PaymentConnectAccountRequested extends PaymentEvent {
  const PaymentConnectAccountRequested();
}

/// Vérifie le statut d'onboarding après retour de la WebView Stripe.
class PaymentOnboardingStatusChecked extends PaymentEvent {
  const PaymentOnboardingStatusChecked();
}

/// Force un re-pull depuis Stripe — utilisé en bouton "Rafraîchir le statut"
/// quand le webhook account.updated n'est pas remonté (dev local sans CLI Stripe,
/// ou délai de propagation en prod).
class PaymentOnboardingRefreshRequested extends PaymentEvent {
  const PaymentOnboardingRefreshRequested();
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
