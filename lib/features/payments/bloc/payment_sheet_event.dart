part of 'payment_sheet_bloc.dart';

sealed class PaymentSheetEvent extends Equatable {
  const PaymentSheetEvent();
  @override
  List<Object?> get props => [];
}

/// Ouverture de la sheet : résout wallet / PayPal / cartes enregistrées.
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

/// Choix de carte : enregistrée (radio) ou nouvelle carte.
class PaymentSheetCardChoiceChanged extends PaymentSheetEvent {
  final CardChoice choice;
  const PaymentSheetCardChoiceChanged(this.choice);
  @override
  List<Object?> get props => [choice];
}

/// Tap sur « Payer {montant} » (stickyBottom) — confirme le choix de carte.
class PaymentSheetPayPressed extends PaymentSheetEvent {
  const PaymentSheetPayPressed();
}

/// Retour de la vue « Nouvelle carte » vers la vue principale (efface le choix).
class PaymentSheetBackToMainPressed extends PaymentSheetEvent {
  const PaymentSheetBackToMainPressed();
}

/// Toggle « Enregistrer cette carte » (PATCH backend, non bloquant).
class PaymentSheetSaveCardToggled extends PaymentSheetEvent {
  final bool save;
  const PaymentSheetSaveCardToggled(this.save);
  @override
  List<Object?> get props => [save];
}
