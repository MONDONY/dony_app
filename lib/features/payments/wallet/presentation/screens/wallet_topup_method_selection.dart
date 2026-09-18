import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';

/// Sélection faite sur l'écran de choix de méthode de recharge
/// ([WalletTopupMethodScreen]), transmise en `extra` à l'écran de montant.
///
/// Remplace l'ancien `extra: String` (seul champ que Stripe utilisait) pour
/// porter en plus, côté mobile money, le numéro payeur déjà confirmé, la
/// devise renvoyée par le catalogue et l'instance du cubit — jamais recréée
/// en aval (écran de montant, écran d'attente) : la recréer perdrait le
/// sondage déjà démarré par `initiate()` et forcerait à relancer
/// `loadProviders`.
///
/// L'opérateur retenu ne voyage pas ici : il vit dans l'état du cubit
/// transmis ([WalletTopupMobileMoneyProvidersReady.selectedProvider]), que
/// `initiate()` relit lui-même.
class WalletTopupMethodSelection {
  const WalletTopupMethodSelection({
    required this.method,
    this.phoneNumber,
    this.currency,
    this.cubit,
  });

  /// `'STRIPE'` ou `'MOBILE_MONEY'`.
  final String method;

  /// Numéro payeur normalisé (mobile money uniquement).
  final String? phoneNumber;

  /// Devise renvoyée par le catalogue d'opérateurs (mobile money uniquement).
  final String? currency;

  /// Même instance que celle créée par l'écran de choix (mobile money
  /// uniquement, `null` pour Stripe).
  final WalletTopupMobileMoneyCubit? cubit;
}
