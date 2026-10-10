import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/commission_funding_alternative.dart';
import 'package:dony/features/matching/data/models/commission_shortfall.dart';

abstract class BidAcceptanceState {}

class BidAcceptanceInitial extends BidAcceptanceState {}

class BidAccepting extends BidAcceptanceState {}

class BidAccepted extends BidAcceptanceState {}

/// Raison d'un échec d'acceptation quand le serveur ne fournit pas de detail
/// exploitable (`serverMessage` vide ou absent) : `display()` choisit alors la
/// clé ARB correspondante — jamais de texte transporté par le bloc.
enum BidFailureReason { confirmFailed, bankAuthInterrupted, refused }

class BidFailed extends BidAcceptanceState {
  final String? serverMessage;
  final BidFailureReason reason;
  final bool cardDeclined;

  /// Erreur métier du serveur (ProblemDetail), quand il y en a une : son
  /// `code` choisit le message du catalogue d'erreurs.
  final AppException? error;

  /// Demande concernée, renseignée sur un refus du serveur.
  final String? bidId;

  /// Refus qui se répéterait à l'identique (trajet complet, trajet fermé…) :
  /// le bouton « Accepter » de cette demande est désactivé.
  final bool definitive;

  BidFailed({
    this.serverMessage,
    required this.reason,
    this.cardDeclined = false,
    this.error,
    this.bidId,
    this.definitive = false,
  });
}

class BidWalletInsufficient extends BidAcceptanceState {
  final double availableBalance;
  final double requiredCommission;
  final bool hasCard;
  final String bidId;
  final String? currency;
  final CommissionShortfall? breakdown;

  /// Devise du trajet, pour proposer de recharger dans cette devise.
  final String? bidCurrency;

  /// Autres portefeuilles utilisables au taux du jour (FLUTTER-CG).
  final List<CommissionFundingAlternative> alternatives;

  BidWalletInsufficient({
    required this.availableBalance,
    required this.requiredCommission,
    required this.hasCard,
    required this.bidId,
    this.currency,
    this.breakdown,
    this.bidCurrency,
    this.alternatives = const [],
  });
}
