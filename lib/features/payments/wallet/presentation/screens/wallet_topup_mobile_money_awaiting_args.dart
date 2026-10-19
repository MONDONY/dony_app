import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';

/// `extra` de la route `/payments/wallet/topup/mobile-money/awaiting`.
///
/// Porte l'instance de [cubit] créée par l'écran Recharger (jamais recréée
/// ici : le sondage démarré par `initiate()` ou `resumePending()` doit
/// continuer sans interruption), ainsi que [phoneNumber] et [amount], pour
/// le récapitulatif et pour « Renvoyer une demande » (même numéro, même
/// montant).
///
/// [phoneNumber] est `null` pour une recharge reprise : le serveur ne
/// renvoie que le numéro masqué, la relance n'est alors pas proposée.
class WalletTopupMobileMoneyAwaitingArgs {
  const WalletTopupMobileMoneyAwaitingArgs({
    required this.cubit,
    required this.phoneNumber,
    required this.amount,
  });

  final WalletTopupMobileMoneyCubit cubit;
  final String? phoneNumber;
  final double amount;
}
