import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
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

/// Étape « Avec quel opérateur ? » d'un bid : aucun dépôt encore lancé,
/// l'expéditeur choisit son numéro payeur et son réseau parmi ceux acceptés
/// par le voyageur. [catalog] nul pendant le premier chargement ; [error]
/// porte un échec de catalogue (bandeau dans l'écran, jamais de snackbar).
/// N'existe pas pour un fil de négociation : le back n'y expose pas de
/// catalogue, l'initiation y reste directe (lot 2, inchangé).
class MobileMoneyPaymentChooseOperator extends MobileMoneyPaymentState {
  const MobileMoneyPaymentChooseOperator({
    required this.status,
    this.catalog,
    this.payerPhone,
    this.isLoadingCatalog = false,
    this.error,
  });
  final MobileMoneyPaymentStatus status;
  final MobileMoneyProviderCatalog? catalog;

  /// Numéro payeur normalisé pour lequel le catalogue a été demandé ; nul
  /// pour le numéro du bid.
  final String? payerPhone;
  final bool isLoadingCatalog;
  final Object? error;

  @override
  List<Object?> get props => [
    status,
    catalog,
    payerPhone,
    isLoadingCatalog,
    error,
  ];
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
