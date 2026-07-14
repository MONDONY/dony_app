part of 'payment_sheet_bloc.dart';

sealed class PaymentSheetEvent extends Equatable {
  const PaymentSheetEvent();
  @override
  List<Object?> get props => [];
}

/// Ouverture de la sheet : résout wallet / PayPal.
class PaymentSheetStarted extends PaymentSheetEvent {
  const PaymentSheetStarted();
}

/// Tap sur le bouton Apple Pay / Google Pay natif.
class PaymentSheetWalletPressed extends PaymentSheetEvent {
  const PaymentSheetWalletPressed();
}

/// Tap sur le bouton PayPal.
class PaymentSheetPayPalPressed extends PaymentSheetEvent {
  const PaymentSheetPayPalPressed();
}

/// Tap sur le bouton « Carte » — ouvre la PaymentSheet native Stripe.
class PaymentSheetCardPressed extends PaymentSheetEvent {
  const PaymentSheetCardPressed();
}
