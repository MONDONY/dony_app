import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:equatable/equatable.dart';

sealed class MobileMoneyAccountEvent extends Equatable {
  const MobileMoneyAccountEvent();

  @override
  List<Object?> get props => [];
}

/// Demande (ou relit) la liste des comptes de versement.
class MobileMoneyAccountsRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountsRequested();
}

/// Ajoute un compte de versement : [provider] est le code pawaPay choisi
/// (`ORANGE_CIV`), [phoneNumber] le numéro en E.164 relu par le voyageur.
class MobileMoneyAccountAddRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountAddRequested({
    required this.phoneNumber,
    required this.provider,
  });
  final String phoneNumber;
  final String provider;

  @override
  List<Object?> get props => [phoneNumber, provider];
}

/// Remplace le numéro d'un compte existant, sans changer d'opérateur.
class MobileMoneyAccountNumberChangeRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountNumberChangeRequested({
    required this.account,
    required this.phoneNumber,
  });
  final MobileMoneyPayoutAccount account;
  final String phoneNumber;

  @override
  List<Object?> get props => [account, phoneNumber];
}

/// Retire un compte de versement.
class MobileMoneyAccountRemoveRequested extends MobileMoneyAccountEvent {
  const MobileMoneyAccountRemoveRequested(this.account);
  final MobileMoneyPayoutAccount account;

  @override
  List<Object?> get props => [account];
}
