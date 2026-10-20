import 'package:dony/features/matching/data/models/mobile_money_accepted_operators.dart';
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

/// Étape « Qui paie ? » d'un colis, d'un fil ou d'un supplément : aucun dépôt
/// vivant, l'expéditeur saisit le numéro qui paie et choisit son opérateur.
/// [accepted] liste les opérateurs que le voyageur accepte ; nul avec un back
/// ancien (404) ou quand leur lecture a échoué : aucune restriction côté app,
/// le back revérifie à l'initiation. [error] porte le refus d'une initiation
/// (422, réseau), affiché en bandeau dans l'étape, jamais en snackbar.
/// [isSubmitting] est vrai pendant l'appel `initiate`.
class MobileMoneyPaymentChoosePayer extends MobileMoneyPaymentState {
  const MobileMoneyPaymentChoosePayer({
    required this.status,
    this.accepted,
    this.error,
    this.isSubmitting = false,
  });
  final MobileMoneyPaymentStatus status;
  final MobileMoneyAcceptedOperators? accepted;
  final Object? error;
  final bool isSubmitting;

  @override
  List<Object?> get props => [status, accepted, error, isSubmitting];
}

/// Un dépôt est en cours côté opérateur (PIN à valider, ou redirection Wave
/// à ouvrir) : l'écran d'attente reste affiché et le sondage continue.
class MobileMoneyPaymentAwaitingConfirmation extends MobileMoneyPaymentState {
  const MobileMoneyPaymentAwaitingConfirmation(this.status);
  final MobileMoneyPaymentStatus status;

  @override
  List<Object?> get props => [status];
}

/// L'échéance est passée mais le dernier dépôt est encore ouvert côté
/// opérateur (CREATED, ACCEPTED, PROCESSING) : le back n'annule rien tant que
/// le dépôt n'a pas de statut final, un code validé à la dernière seconde
/// aboutit encore. L'écran affiche « Pas encore validé » et le sondage
/// continue jusqu'au séquestre, au refus ou à l'expiration.
class MobileMoneyPaymentOverdue extends MobileMoneyPaymentState {
  const MobileMoneyPaymentOverdue(this.status);
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

/// Le bid a été annulé, ou la fenêtre pour payer est dépassée sans séquestre
/// ni dépôt encore ouvert (sinon [MobileMoneyPaymentOverdue]).
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
