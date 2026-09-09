import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:equatable/equatable.dart';

sealed class MobileMoneyPaymentState extends Equatable {
  const MobileMoneyPaymentState();

  @override
  List<Object?> get props => [];
}

class MobileMoneyPaymentInitial extends MobileMoneyPaymentState {
  const MobileMoneyPaymentInitial();
}

class MobileMoneyPaymentLoading extends MobileMoneyPaymentState {
  const MobileMoneyPaymentLoading();
}

/// Un dépôt est en cours côté opérateur (PIN à valider, ou redirection Wave
/// à ouvrir) : l'écran d'attente reste affiché et le sondage continue.
class MobileMoneyPaymentAwaitingConfirmation extends MobileMoneyPaymentState {
  const MobileMoneyPaymentAwaitingConfirmation(this.status);
  final MobileMoneyPaymentStatus status;

  @override
  List<Object?> get props => [status];
}

/// Le paiement est séquestré (ou déjà versé) : le flux se termine en succès.
class MobileMoneyPaymentEscrowed extends MobileMoneyPaymentState {
  const MobileMoneyPaymentEscrowed(this.status);
  final MobileMoneyPaymentStatus status;

  @override
  List<Object?> get props => [status];
}

/// Le dernier dépôt tenté a été refusé par l'opérateur : il faut relancer
/// une nouvelle tentative pour continuer.
class MobileMoneyPaymentDepositFailed extends MobileMoneyPaymentState {
  const MobileMoneyPaymentDepositFailed(this.status);
  final MobileMoneyPaymentStatus status;

  @override
  List<Object?> get props => [status];
}

/// Le bid a été annulé, ou la fenêtre de 30 minutes pour payer est dépassée
/// sans que le paiement ait été séquestré.
class MobileMoneyPaymentExpired extends MobileMoneyPaymentState {
  const MobileMoneyPaymentExpired(this.status);
  final MobileMoneyPaymentStatus status;

  @override
  List<Object?> get props => [status];
}

/// Échec technique (réseau, validation, serveur). [error] est toujours une
/// `AppException` produite par `unwrapDioError` : jamais affichée brute côté
/// UI, toujours via `ErrorPresenter`/`ErrorCatalog`.
class MobileMoneyPaymentError extends MobileMoneyPaymentState {
  const MobileMoneyPaymentError(this.error);
  final Object error;

  @override
  List<Object?> get props => [error];
}
