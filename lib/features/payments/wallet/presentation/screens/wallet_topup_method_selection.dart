import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';

/// Sélection faite sur l'écran de choix de méthode de recharge
/// ([WalletTopupMethodScreen]), transmise en `extra` à l'écran de montant.
///
/// Remplace l'ancien `extra: String` (seul champ que Stripe utilisait) pour
/// porter en plus, côté mobile money, le numéro payeur déjà confirmé, la
/// devise du pays (ou du catalogue d'opérateurs de l'ancien parcours),
/// l'opérateur choisi et l'instance du cubit — jamais recréée en aval (écran
/// de montant, écran d'attente) : la recréer perdrait le sondage déjà
/// démarré par `initiate()` et forcerait à relancer `loadProviders`.
///
/// Le code de l'opérateur est aussi confié au cubit
/// ([WalletTopupMobileMoneyCubit.useOperator]) avant de pousser l'écran de
/// montant : c'est lui que `initiate()` envoie au back. [operator] sert à
/// l'affichage (nom, pastille) et aux bornes de montant.
class WalletTopupMethodSelection {
  const WalletTopupMethodSelection({
    required this.method,
    this.phoneNumber,
    this.currency,
    this.cubit,
    this.operator,
  });

  /// `'STRIPE'` ou `'MOBILE_MONEY'`.
  final String method;

  /// Numéro payeur normalisé, E.164 (mobile money uniquement).
  final String? phoneNumber;

  /// Devise de la recharge mobile money (mobile money uniquement).
  final String? currency;

  /// Même instance que celle créée par l'écran de choix (mobile money
  /// uniquement, `null` pour Stripe).
  final WalletTopupMobileMoneyCubit? cubit;

  /// Opérateur choisi dans le bloc « compte qui paie », avec ses montants
  /// limites et sa façon de faire valider le paiement. `null` pour Stripe et
  /// pour l'ancien parcours (back sans catalogue des pays), où l'opérateur
  /// vit dans l'état du cubit.
  final MobileMoneyOperator? operator;
}
