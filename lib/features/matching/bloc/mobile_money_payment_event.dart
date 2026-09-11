import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:equatable/equatable.dart';

sealed class MobileMoneyPaymentEvent extends Equatable {
  const MobileMoneyPaymentEvent();

  @override
  List<Object?> get props => [];
}

/// Ouverture de l'écran d'attente : lit le statut courant de la portée
/// ([MobileMoneyScope], un bid ou un fil de négociation) ; sans dépôt vivant
/// ni séquestre déjà atteint, lance l'initiation d'un premier dépôt avec
/// [phoneNumber] si l'appelant en connaît déjà un (numéro payeur pré-rempli).
class MobileMoneyPaymentOpened extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentOpened({required this.scope, this.phoneNumber});
  final MobileMoneyScope scope;
  final String? phoneNumber;

  @override
  List<Object?> get props => [scope, phoneNumber];
}

/// Nouvel essai de dépôt, déclenché par l'utilisateur (lien expiré, dépôt
/// refusé), éventuellement avec un autre numéro payeur.
class MobileMoneyPaymentInitiateRequested extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentInitiateRequested({
    required this.scope,
    this.phoneNumber,
  });
  final MobileMoneyScope scope;
  final String? phoneNumber;

  @override
  List<Object?> get props => [scope, phoneNumber];
}

/// Sondage périodique du statut : silencieux, ne passe jamais par Loading
/// pour éviter de faire clignoter l'écran pendant l'attente.
class MobileMoneyStatusPolled extends MobileMoneyPaymentEvent {
  const MobileMoneyStatusPolled({required this.scope});
  final MobileMoneyScope scope;

  @override
  List<Object?> get props => [scope];
}
