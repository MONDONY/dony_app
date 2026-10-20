import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:equatable/equatable.dart';

/// Action d'écriture menée à bien sur les comptes de versement.
enum MobileMoneyAccountAction { added, numberChanged, removed }

sealed class MobileMoneyAccountState extends Equatable {
  const MobileMoneyAccountState();

  /// Dernière liste connue, `null` tant qu'aucune lecture n'a abouti.
  MobileMoneyPayoutAccounts? get data => null;

  @override
  List<Object?> get props => [];
}

class MobileMoneyAccountInitial extends MobileMoneyAccountState {
  const MobileMoneyAccountInitial();
}

class MobileMoneyAccountLoading extends MobileMoneyAccountState {
  const MobileMoneyAccountLoading();
}

/// Liste lue. [submitting] : une écriture (ajout, changement de numéro,
/// retrait) est en vol, l'écran reste affiché sur la liste.
class MobileMoneyAccountLoaded extends MobileMoneyAccountState {
  const MobileMoneyAccountLoaded(this.data, {this.submitting = false});

  @override
  final MobileMoneyPayoutAccounts data;
  final bool submitting;

  @override
  List<Object?> get props => [data, submitting];
}

/// Écriture réussie : [data] est la liste relue après l'action (celle d'avant
/// si la relecture a échoué).
class MobileMoneyAccountActionDone extends MobileMoneyAccountState {
  const MobileMoneyAccountActionDone(this.data, this.action);

  @override
  final MobileMoneyPayoutAccounts data;
  final MobileMoneyAccountAction action;

  @override
  List<Object?> get props => [data, action];
}

/// Écriture refusée : [data] est la liste d'avant l'action, [error] toujours
/// l'exception issue de `unwrapDioError` (jamais une chaîne).
class MobileMoneyAccountActionFailed extends MobileMoneyAccountState {
  const MobileMoneyAccountActionFailed(this.data, this.error);

  @override
  final MobileMoneyPayoutAccounts data;
  final Object error;

  @override
  List<Object?> get props => [data, error];
}

/// Lecture de la liste en échec : l'écran propose de réessayer.
class MobileMoneyAccountError extends MobileMoneyAccountState {
  const MobileMoneyAccountError(this.error);

  /// Toujours l'exception issue de `unwrapDioError` (jamais une chaîne), pour
  /// que l'écran appelle `ErrorPresenter.show(context, error)`.
  final Object error;

  @override
  List<Object?> get props => [error];
}
