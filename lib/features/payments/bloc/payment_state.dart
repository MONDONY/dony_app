part of 'payment_bloc.dart';

sealed class PaymentState extends Equatable {
  const PaymentState();
  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {
  const PaymentInitial();
}

class PaymentLoading extends PaymentState {
  const PaymentLoading();
}

/// Payment sheet ready for bid checkout flow.
class CheckoutPaymentSheetReady extends PaymentState {
  final String clientSecret;
  final String publishableKey;
  final String bidId;
  final double amountEur;
  final List<String> paymentMethodTypes;

  const CheckoutPaymentSheetReady({
    required this.clientSecret,
    required this.publishableKey,
    required this.bidId,
    required this.amountEur,
    this.paymentMethodTypes = const [],
  });

  @override
  List<Object?> get props =>
      [clientSecret, publishableKey, bidId, amountEur, paymentMethodTypes];
}

/// URL d'onboarding Stripe prête — naviguer vers la WebView.
class PaymentOnboardingUrlReady extends PaymentState {
  final String url;
  const PaymentOnboardingUrlReady(this.url);
  @override
  List<Object?> get props => [url];
}

/// Onboarding complété — charges_enabled = true côté Stripe.
class PaymentOnboardingComplete extends PaymentState {
  const PaymentOnboardingComplete();
}

/// Onboarding en attente — Stripe n'a pas encore validé le compte.
class PaymentOnboardingPending extends PaymentState {
  const PaymentOnboardingPending();
}

/// PaymentIntent créé — clientSecret prêt pour la feuille de paiement Stripe.
class PaymentSheetReady extends PaymentState {
  final String clientSecret;
  final double amount;
  final double commissionAmount;
  final String paymentId;

  const PaymentSheetReady({
    required this.clientSecret,
    required this.amount,
    required this.commissionAmount,
    required this.paymentId,
  });

  @override
  List<Object?> get props => [clientSecret, amount, commissionAmount, paymentId];
}

/// Feuille de paiement complétée — escrow actif, en attente de livraison.
class PaymentEscrowPending extends PaymentState {
  final double amount;
  const PaymentEscrowPending(this.amount);
  @override
  List<Object?> get props => [amount];
}

class PaymentError extends PaymentState {
  final AppException error;
  const PaymentError(this.error);
  @override
  List<Object?> get props => [error];
}
