import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:equatable/equatable.dart';

/// États de [WalletTopupMobileMoneyCubit] : chargement des opérateurs
/// utilisables sur le numéro payeur, initiation (ou reprise) de la recharge,
/// puis sondage du statut jusqu'à confirmation ou échec, en passant par
/// « pas encore validé » une fois l'échéance dépassée.
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

/// Délai de validation retenu quand le back ne donne pas d'échéance
/// (`expiresAt` absent d'un back ancien).
const walletTopupFallbackExpiry = Duration(minutes: 15);

/// Recharge initiée (ou reprise), en attente de confirmation opérateur.
/// [startedAt] sert au repli quand le back ne donne pas d'échéance.
/// [amount] : montant de la recharge, connu de l'app ou relu sur le serveur
/// pour une recharge reprise. [resumed] : recharge reprise du serveur
/// (`GET /wallet/topup/pending`), dont le numéro n'est connu que masqué.
class WalletTopupMobileMoneyAwaiting extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyAwaiting({
    required this.topup,
    required this.startedAt,
    this.amount,
    this.resumed = false,
  });

  final WalletTopupModel topup;
  final DateTime startedAt;
  final double? amount;
  final bool resumed;

  /// Échéance du chrono : celle du serveur, sinon [startedAt] + 15 min.
  DateTime get expiresAt =>
      topup.expiresAt ?? startedAt.add(walletTopupFallbackExpiry);

  @override
  List<Object?> get props => [topup, startedAt, amount, resumed];
}

/// Échéance passée sans statut final : l'opérateur peut encore valider, le
/// sondage continue. Jamais un échec : seul le back déclare un `FAILED`.
class WalletTopupMobileMoneyOverdue extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyOverdue({required this.topup});

  final WalletTopupModel topup;

  @override
  List<Object?> get props => [topup];
}

/// Recharge confirmée : portefeuille crédité. [resumed] : recharge reprise
/// à l'ouverture de l'écran 1 ; son numéro n'est connu que masqué, il n'est
/// donc pas mémorisé pour la prochaine fois.
class WalletTopupMobileMoneyConfirmed extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyConfirmed(this.status, {this.resumed = false});

  final WalletTopupStatusModel status;
  final bool resumed;

  @override
  List<Object?> get props => [status, resumed];
}

/// Recharge refusée, confirmé par l'opérateur (`FAILED` du back).
/// [failureCode] : code Yadony (`insufficient-balance`, `not-approved`...),
/// traduit par l'écran ; [failureReason] : texte déjà traduit par le back,
/// nettoyé, jamais vide, en repli d'un code inconnu de l'app.
class WalletTopupMobileMoneyFailed extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyFailed({this.failureCode, this.failureReason});

  final String? failureCode;
  final String? failureReason;

  @override
  List<Object?> get props => [failureCode, failureReason];
}

/// Erreur technique (réseau, serveur) sur `loadProviders` ou `initiate`.
class WalletTopupMobileMoneyError extends WalletTopupMobileMoneyState {
  const WalletTopupMobileMoneyError(this.error);

  final AppException error;

  @override
  List<Object?> get props => [error];
}
