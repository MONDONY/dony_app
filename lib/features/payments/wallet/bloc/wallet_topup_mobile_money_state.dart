import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:equatable/equatable.dart';

/// États de [WalletTopupMobileMoneyCubit] : chargement des opérateurs
/// utilisables sur le numéro payeur, initiation de la recharge, puis
/// sondage du statut jusqu'à confirmation, échec ou expiration.
sealed class WalletTopupMobileMoneyState extends Equatable {
  const WalletTopupMobileMoneyState();

  @override
  List<Object?> get props => [];
}

/// Aucune action encore lancée.
class WalletTopupMobileMoneyIdle extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyIdle();
}

/// Chargement du catalogue d'opérateurs (`loadProviders`).
class WalletTopupMobileMoneyProvidersLoading
    extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyProvidersLoading();
}

/// Catalogue chargé. [selectedProvider] est pré-rempli avec l'opérateur
/// détecté par pawaPay pour ce numéro (`catalog.detected`), et peut être
/// changé par [WalletTopupMobileMoneyCubit.selectProvider].
class WalletTopupMobileMoneyProvidersReady extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyProvidersReady({
    required this.catalog,
    this.selectedProvider,
  });

  final MobileMoneyProviderCatalog catalog;
  final String? selectedProvider;

  @override
  List<Object?> get props => [catalog, selectedProvider];
}

/// Appel `topupMobileMoney` en cours.
class WalletTopupMobileMoneyInitiating extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyInitiating();
}

/// Recharge initiée, en attente de confirmation opérateur. [startedAt] sert
/// de référence pour l'expiration (15 min) du sondage.
class WalletTopupMobileMoneyAwaiting extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyAwaiting({
    required this.topup,
    required this.startedAt,
  });

  final WalletTopupModel topup;
  final DateTime startedAt;

  @override
  List<Object?> get props => [topup, startedAt];
}

/// Recharge confirmée : portefeuille crédité.
class WalletTopupMobileMoneyConfirmed extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyConfirmed(this.status);

  final WalletTopupStatusModel status;

  @override
  List<Object?> get props => [status];
}

/// Recharge refusée par l'opérateur, ou sondage expiré (15 min) sans
/// confirmation. [message] est déjà prêt à afficher à l'utilisateur.
class WalletTopupMobileMoneyFailed extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Erreur technique (réseau, serveur) sur `loadProviders` ou `initiate`.
class WalletTopupMobileMoneyError extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyError(this.error);

  final AppException error;

  @override
  List<Object?> get props => [error];
}
