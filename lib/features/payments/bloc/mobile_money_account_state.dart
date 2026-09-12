import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
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
  const MobileMoneyAccountLoaded(this.account, {this.editingNumber = false});
  final MobileMoneyAccount account;

  /// Vrai quand le voyageur a demandé à changer son numéro depuis la vue
  /// active : l'écran affiche alors le formulaire malgré un compte actif.
  final bool editingNumber;

  @override
  List<Object?> get props => [account, editingNumber];
}

/// Activation ou désactivation en cours. Porte le dernier compte connu (ou
/// le compte par défaut non configuré) pour que l'écran reste affichable
/// pendant l'appel réseau, sans clignoter vers un état vide.
class MobileMoneyAccountUpdating extends MobileMoneyAccountState {
  const MobileMoneyAccountUpdating(this.account, {this.editingNumber = false});
  final MobileMoneyAccount account;
  final bool editingNumber;

  @override
  List<Object?> get props => [account, editingNumber];
}

/// Catalogue des réseaux en cours de chargement (squelette dans l'écran).
class MobileMoneyAccountProvidersLoading extends MobileMoneyAccountState {
  const MobileMoneyAccountProvidersLoading(
    this.account, {
    this.editingNumber = false,
  });
  final MobileMoneyAccount account;
  final bool editingNumber;

  @override
  List<Object?> get props => [account, editingNumber];
}

/// Catalogue chargé : la liste des réseaux à cocher s'affiche.
class MobileMoneyAccountProvidersLoaded extends MobileMoneyAccountState {
  const MobileMoneyAccountProvidersLoaded(
    this.account,
    this.catalog, {
    this.editingNumber = false,
  });
  final MobileMoneyAccount account;
  final MobileMoneyProviderCatalog catalog;
  final bool editingNumber;

  @override
  List<Object?> get props => [account, catalog, editingNumber];
}

/// Catalogue en échec (numéro inconnu, pawaPay muet) : bandeau dans
/// l'écran, jamais de snackbar, le formulaire reste saisissable.
class MobileMoneyAccountProvidersError extends MobileMoneyAccountState {
  const MobileMoneyAccountProvidersError(
    this.account,
    this.error, {
    this.editingNumber = false,
  });
  final MobileMoneyAccount account;
  final Object error;
  final bool editingNumber;

  @override
  List<Object?> get props => [account, error, editingNumber];
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
