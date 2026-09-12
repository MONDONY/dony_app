import 'package:equatable/equatable.dart';

sealed class MobileMoneyAccountEvent extends Equatable {
  const MobileMoneyAccountEvent();

  @override
  List<Object?> get props => [];
}

/// Demande le compte de versement courant (`GET /payments/mobile-money/account`).
class MobileMoneyAccountRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountRequested();
}

/// Active (ou réactive) le versement avec le numéro saisi et les réseaux
/// cochés (codes pawaPay, ordre du catalogue). Liste vide : le back ne
/// retient que l'opérateur prédit.
class MobileMoneyAccountActivateRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountActivateRequested({
    this.phoneNumber,
    this.providers = const [],
  });
  final String? phoneNumber;
  final List<String> providers;

  @override
  List<Object?> get props => [phoneNumber, providers];
}

/// Désactive le versement mobile money pour le voyageur connecté.
class MobileMoneyAccountDisableRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountDisableRequested();
}

/// Catalogue des réseaux d'un numéro saisi, ou du numéro déjà enregistré
/// quand [phoneNumber] est nul (feuille « Réseaux acceptés »).
class MobileMoneyAccountProvidersRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountProvidersRequested({this.phoneNumber});
  final String? phoneNumber;

  @override
  List<Object?> get props => [phoneNumber];
}

/// Les deux saisies ne coïncident plus : la liste des réseaux disparaît.
class MobileMoneyAccountProvidersCleared extends MobileMoneyAccountEvent {
  const MobileMoneyAccountProvidersCleared();
}

/// Remplace les réseaux acceptés du compte actif, sans ressaisir le numéro.
class MobileMoneyAccountProvidersUpdateRequested
    extends MobileMoneyAccountEvent {
  const MobileMoneyAccountProvidersUpdateRequested(this.providers);
  final List<String> providers;

  @override
  List<Object?> get props => [providers];
}

/// « Changer de numéro » depuis la vue active : rouvre le formulaire.
class MobileMoneyAccountChangeNumberRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountChangeNumberRequested();
}

/// « Annuler » du formulaire de changement de numéro : retour à la vue active.
class MobileMoneyAccountChangeNumberCancelled extends MobileMoneyAccountEvent {
  const MobileMoneyAccountChangeNumberCancelled();
}
