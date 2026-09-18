import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';

/// `extra` de la route `/payments/wallet/topup/mobile-money/awaiting`.
///
/// Porte l'instance de [cubit] créée par l'écran de choix (jamais recréée
/// ici : le sondage démarré par `initiate()` doit continuer sans
/// interruption), ainsi que [phoneNumber] et [amount] — nécessaires pour
/// qu'un « Réessayer » après un [WalletTopupMobileMoneyFailed] puisse
/// relancer la même recharge sans redemander ces deux informations.
class WalletTopupMobileMoneyAwaitingArgs {
  const WalletTopupMobileMoneyAwaitingArgs({
    required this.cubit,
    required this.phoneNumber,
    required this.amount,
  });

  final WalletTopupMobileMoneyCubit cubit;
  final String phoneNumber;
  final double amount;
}
