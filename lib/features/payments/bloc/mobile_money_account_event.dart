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
///
/// [phoneNumber] : numéro saisi par le voyageur, transmis seulement quand
/// son compte Firebase n'a pas de téléphone (vérification SMS pas encore
/// configurée) — voir `MobileMoneyAccountPhoneRequired`. Le backend ignore
/// ce champ si le compte a déjà un numéro vérifié.
class MobileMoneyAccountActivateRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountActivateRequested({this.phoneNumber});

  final String? phoneNumber;

  @override
  List<Object?> get props => [phoneNumber];
}

/// Désactive le versement mobile money pour le voyageur connecté.
class MobileMoneyAccountDisableRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountDisableRequested();
}
