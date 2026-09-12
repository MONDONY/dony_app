import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:equatable/equatable.dart';

sealed class MobileMoneyPaymentEvent extends Equatable {
  const MobileMoneyPaymentEvent();

  @override
  List<Object?> get props => [];
}

/// Ouverture de l'écran d'attente : lit le statut courant de la portée
/// ([MobileMoneyScope], un bid ou un fil de négociation). Sans dépôt vivant
/// ni séquestre déjà atteint : pour un bid, charge le catalogue des réseaux
/// acceptés par le voyageur et attend le choix de l'expéditeur (voir
/// [MobileMoneyPaymentProvidersRequested]) ; pour un fil de négociation, le
/// back n'expose pas de catalogue et l'initiation d'un premier dépôt est
/// lancée directement, avec [phoneNumber] si l'appelant en connaît déjà un
/// (numéro payeur pré-rempli).
class MobileMoneyPaymentOpened extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentOpened({required this.scope, this.phoneNumber});
  final MobileMoneyScope scope;
  final String? phoneNumber;

  @override
  List<Object?> get props => [scope, phoneNumber];
}

/// Lance un dépôt avec le numéro payeur ([phoneNumber], sinon celui du bid
/// ou du fil) et l'opérateur choisi ([provider], sinon celui prédit par le
/// back) : nouvel essai déclenché par l'utilisateur (lien expiré, dépôt
/// refusé), ou validation du choix d'opérateur depuis
/// [MobileMoneyPaymentChooseOperator].
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

/// (Re)charge le catalogue des réseaux avec lesquels l'expéditeur d'un bid
/// peut payer, pour son numéro ([phoneNumber], sinon celui du bid). Depuis
/// un dépôt refusé (`DepositFailed`), ramène à l'étape de choix de
/// l'opérateur plutôt que de relancer directement un dépôt.
class MobileMoneyPaymentProvidersRequested extends MobileMoneyPaymentEvent {
  const MobileMoneyPaymentProvidersRequested({
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
