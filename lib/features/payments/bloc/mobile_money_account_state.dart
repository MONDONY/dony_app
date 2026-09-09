import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:equatable/equatable.dart';

sealed class MobileMoneyAccountState extends Equatable {
  const MobileMoneyAccountState();

  @override
  List<Object?> get props => [];
}

class MobileMoneyAccountInitial extends MobileMoneyAccountState {
  const MobileMoneyAccountInitial();
}

class MobileMoneyAccountLoading extends MobileMoneyAccountState {
  const MobileMoneyAccountLoading();
}

class MobileMoneyAccountLoaded extends MobileMoneyAccountState {
  const MobileMoneyAccountLoaded(this.account);

  final MobileMoneyAccount account;

  @override
  List<Object?> get props => [account];
}

/// Activation ou désactivation en cours. Porte le dernier compte connu (ou
/// le compte par défaut non configuré) pour que l'écran reste affichable
/// pendant l'appel réseau, sans clignoter vers un état vide.
class MobileMoneyAccountUpdating extends MobileMoneyAccountState {
  const MobileMoneyAccountUpdating(this.account);

  final MobileMoneyAccount account;

  @override
  List<Object?> get props => [account];
}

/// Activation refusée par le backend faute de numéro disponible (compte
/// Firebase sans téléphone, et aucun `phoneNumber` fourni dans l'event) :
/// distinct de [MobileMoneyAccountError] pour que l'écran affiche un
/// formulaire de saisie plutôt qu'une snackbar d'erreur.
class MobileMoneyAccountPhoneRequired extends MobileMoneyAccountState {
  const MobileMoneyAccountPhoneRequired(this.account);

  /// Dernier compte connu (ou le compte par défaut non configuré),
  /// conservé pour que l'écran reste affichable pendant que l'utilisateur
  /// saisit son numéro.
  final MobileMoneyAccount account;

  @override
  List<Object?> get props => [account];
}

class MobileMoneyAccountError extends MobileMoneyAccountState {
  const MobileMoneyAccountError(this.error, {this.account});

  /// Toujours l'exception issue de `unwrapDioError` (jamais une chaîne), pour
  /// que l'écran appelle `ErrorPresenter.show(context, error)`.
  final Object error;

  /// Dernier compte connu, conservé lors d'un échec d'activation ou de
  /// désactivation pour que l'écran reste affichable. Absent pour un simple
  /// échec de chargement (`MobileMoneyAccountRequested`).
  final MobileMoneyAccount? account;

  @override
  List<Object?> get props => [error, account];
}
