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

/// Active (ou réactive) le versement mobile money pour le voyageur connecté.
class MobileMoneyAccountActivateRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountActivateRequested();
}

/// Désactive le versement mobile money pour le voyageur connecté.
class MobileMoneyAccountDisableRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountDisableRequested();
}
