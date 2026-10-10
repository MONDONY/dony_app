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

/// Raison d'un [PaymentSheetFailure], pour l'affichage d'un libellé générique
/// quand aucun [PaymentSheetFailure.providerMessage] n'est disponible.
///
/// - [declined] : vrai refus carte (`card_error`), seul cas avec message du
///   fournisseur ;
/// - [sheetUnavailable] : la feuille Stripe/PayPal n'a pas pu s'ouvrir (erreur
///   locale du SDK, FLUTTER-CJ) — ce n'est pas un refus de la carte ;
/// - [generic] : tout autre échec.
enum PaymentSheetFailureReason {
  cardUnavailable,
  declined,

  /// Vérification 3-D Secure de la banque non aboutie (FLUTTER-G5).
  authenticationFailed,
  sheetUnavailable,
  generic,
}

/// Échec transitoire (snackbar) — immédiatement suivi d'un retour à [ready].
///
/// Ne porte plus de texte : [providerMessage], quand présent (vrai refus
/// carte seulement), est le message déjà localisé par le SDK Stripe
/// (`localizedMessage`) dans la langue du téléphone — affiché tel quel. Sans
/// lui, l'UI affiche le libellé générique associé à [reason].
class PaymentSheetFailure extends PaymentSheetState {
  final String? providerMessage;
  final PaymentSheetFailureReason reason;
  final PaymentSheetResolved ready;
  const PaymentSheetFailure({
    this.providerMessage,
    required this.reason,
    required this.ready,
  });
  @override
  List<Object?> get props => [providerMessage, reason, ready];
}
