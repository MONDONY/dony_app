import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:equatable/equatable.dart';

sealed class MobileMoneyPaymentEvent extends Equatable {
  const MobileMoneyPaymentEvent();
}

/// Ouverture de l'écran de paiement : lit le statut courant de la portée
/// ([MobileMoneyScope] : un bid, un fil de négociation ou un supplément).
/// Un dépôt déjà vivant reprend l'attente sans second dépôt ; sans dépôt
/// vivant ni séquestre, les opérateurs acceptés par le voyageur sont lus et
/// l'étape « Qui paie ? » s'affiche (`MobileMoneyPaymentChoosePayer`).
class MobileMoneyPaymentOpened extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentOpened({required this.scope});
  final MobileMoneyScope scope;

  @override
  List<Object?> get props => [scope];
}

/// Lance un dépôt avec le numéro payeur ([phoneNumber], sinon celui du bid
/// ou du fil côté back) et l'opérateur choisi ([provider], sinon celui prédit
/// par le back) : validation de l'étape « Qui paie ? ». Un dépôt créé avec un
/// numéro connu garde ce couple pour [MobileMoneyPaymentResendRequested].
class MobileMoneyPaymentInitiateRequested extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentInitiateRequested({
    required this.scope,
    this.phoneNumber,
    this.provider,
  });
  final MobileMoneyScope scope;
  final String? phoneNumber;
  final String? provider;

  @override
  List<Object?> get props => [scope, phoneNumber, provider];
}

/// « Renvoyer une demande » après un dépôt refusé : relance un dépôt avec le
/// dernier couple numéro + opérateur connu. Sans couple connu (écran rouvert
/// depuis une notification, numéro complet inconnu), ne fait rien.
class MobileMoneyPaymentResendRequested extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentResendRequested({required this.scope});
  final MobileMoneyScope scope;

  @override
  List<Object?> get props => [scope];
}

/// « Payer avec un autre numéro » après un dépôt refusé : retour à l'étape
/// « Qui paie ? », opérateurs acceptés réutilisés sans nouvel appel.
class MobileMoneyPaymentChangePayerRequested extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentChangePayerRequested({required this.scope});
  final MobileMoneyScope scope;

  @override
  List<Object?> get props => [scope];
}

/// Sondage périodique du statut : silencieux, ne passe jamais par Loading
/// pour éviter de faire clignoter l'écran pendant l'attente.
class MobileMoneyStatusPolled extends MobileMoneyPaymentEvent {
  const MobileMoneyStatusPolled({required this.scope});
  final MobileMoneyScope scope;

  @override
  List<Object?> get props => [scope];
}
