part of 'payment_sheet_bloc.dart';

enum PaymentMethodKind { wallet, paypal, card }

sealed class PaymentSheetState extends Equatable {
  const PaymentSheetState();
  @override
  List<Object?> get props => [];
}

class PaymentSheetLoading extends PaymentSheetState {
  const PaymentSheetLoading();
}

/// Moyens résolus — la sheet est utilisable.
class PaymentSheetResolved extends PaymentSheetState {
  final bool walletAvailable;
  final bool paypalAvailable;

  const PaymentSheetResolved({
    required this.walletAvailable,
    required this.paypalAvailable,
  });

  @override
  List<Object?> get props => [walletAvailable, paypalAvailable];
}

/// Confirmation en cours — [ready] garde la vue affichée derrière le loader.
class PaymentSheetProcessing extends PaymentSheetState {
  final PaymentSheetResolved ready;
  final PaymentMethodKind method;
  const PaymentSheetProcessing({required this.ready, required this.method});
  @override
  List<Object?> get props => [ready, method];
}

/// Paiement autorisé — la sheet affiche la vue succès.
class PaymentSheetSuccess extends PaymentSheetState {
  final PaymentMethodKind method;
  const PaymentSheetSuccess({required this.method});
  @override
  List<Object?> get props => [method];
}

/// Échec transitoire (snackbar) — immédiatement suivi d'un retour à [ready].
class PaymentSheetFailure extends PaymentSheetState {
  final String message;
  final PaymentSheetResolved ready;
  const PaymentSheetFailure({required this.message, required this.ready});
  @override
  List<Object?> get props => [message, ready];
}
