import 'package:equatable/equatable.dart';

/// Etat d'un depot mobile money tente cote pawaPay.
enum MobileMoneyDepositStatus {
  created,
  accepted,
  processing,
  completed,
  failed,
  submitRejected,
  unknown,
}

/// Dernier depot mobile money tente pour un bid (nul tant qu'aucune
/// tentative n'a ete faite). Fait partie de `MobileMoneyPaymentStatus`.
class MobileMoneyDeposit extends Equatable {
  const MobileMoneyDeposit({
    required this.id,
    required this.status,
    this.providerLabel,
    this.msisdnMasked,
    this.authorizationUrl,
    this.failureCode,
    this.failureMessage,
  });

  final String id;
  final MobileMoneyDepositStatus status;
  final String? providerLabel;
  final String? msisdnMasked;

  /// Non nul uniquement pour Wave : l'app doit rediriger vers cette URL
  /// plutot que d'afficher la consigne de validation du code PIN.
  final String? authorizationUrl;
  final String? failureCode;
  final String? failureMessage;

  factory MobileMoneyDeposit.fromJson(Map<String, dynamic> json) =>
      MobileMoneyDeposit(
        id: json['id'] as String,
        status: _statusFromJson(json['status'] as String?),
        providerLabel: json['providerLabel'] as String?,
        msisdnMasked: json['msisdnMasked'] as String?,
        authorizationUrl: json['authorizationUrl'] as String?,
        failureCode: json['failureCode'] as String?,
        failureMessage: json['failureMessage'] as String?,
      );

  /// Depot en cours cote operateur (PIN pas encore valide, ou en attente
  /// de confirmation Wave) : l'ecran d'attente doit rester ouvert.
  bool get isLive =>
      status == MobileMoneyDepositStatus.created ||
      status == MobileMoneyDepositStatus.accepted ||
      status == MobileMoneyDepositStatus.processing;

  /// Depot rejete : plus aucune action possible sans relancer un paiement.
  bool get isFailed =>
      status == MobileMoneyDepositStatus.failed ||
      status == MobileMoneyDepositStatus.submitRejected;

  static MobileMoneyDepositStatus _statusFromJson(String? raw) {
    switch (raw) {
      case 'CREATED':
        return MobileMoneyDepositStatus.created;
      case 'ACCEPTED':
        return MobileMoneyDepositStatus.accepted;
      case 'PROCESSING':
        return MobileMoneyDepositStatus.processing;
      case 'COMPLETED':
        return MobileMoneyDepositStatus.completed;
      case 'FAILED':
        return MobileMoneyDepositStatus.failed;
      case 'SUBMIT_REJECTED':
        return MobileMoneyDepositStatus.submitRejected;
      default:
        return MobileMoneyDepositStatus.unknown;
    }
  }

  @override
  List<Object?> get props => [
    id,
    status,
    providerLabel,
    msisdnMasked,
    authorizationUrl,
    failureCode,
    failureMessage,
  ];
}

/// Statut de paiement mobile money d'un bid, renvoye par
/// `POST .../mobile-money/accept`, `POST .../mobile-money/initiate` et
/// `GET .../mobile-money/status`.
class MobileMoneyPaymentStatus extends Equatable {
  const MobileMoneyPaymentStatus({
    required this.bidId,
    required this.bidStatus,
    this.paymentStatus,
    this.deadlineAt,
    this.amount,
    this.currency = 'XOF',
    this.deposit,
  });

  final String bidId;
  final String bidStatus;

  /// `PENDING`, `ESCROW`, `RELEASED`, `REFUNDED`, `CANCELLED`, ou nul tant
  /// qu'aucun paiement n'a ete initie.
  final String? paymentStatus;

  /// Fin de la fenetre de 30 minutes pour payer. Renvoyee par le backend en
  /// heure locale UTC sans suffixe de zone.
  final DateTime? deadlineAt;
  final double? amount;
  final String currency;

  /// Dernier depot tente, nul tant qu'aucune tentative n'a ete faite.
  final MobileMoneyDeposit? deposit;

  factory MobileMoneyPaymentStatus.fromJson(Map<String, dynamic> json) =>
      MobileMoneyPaymentStatus(
        bidId: json['bidId'] as String,
        bidStatus: json['bidStatus'] as String,
        paymentStatus: json['paymentStatus'] as String?,
        deadlineAt: _parseUtc(json['deadlineAt'] as String?),
        amount: (json['amount'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'XOF',
        deposit: json['deposit'] != null
            ? MobileMoneyDeposit.fromJson(
                json['deposit'] as Map<String, dynamic>,
              )
            : null,
      );

  /// Paiement deja seguestre (ou verse) : le compte a rebours ne s'applique
  /// plus et l'ecran d'attente doit se refermer sur un succes.
  bool get isEscrowed =>
      paymentStatus == 'ESCROW' || paymentStatus == 'RELEASED';

  /// Un depot est en cours cote operateur.
  bool get isDepositLive => deposit?.isLive ?? false;

  /// Le dernier depot tente a echoue.
  bool get isDepositFailed => deposit?.isFailed ?? false;

  /// Le bid a ete annule, ou le delai de paiement de 30 minutes est depasse
  /// sans que le paiement ait ete sequestre.
  bool isExpired(DateTime now) =>
      bidStatus == 'CANCELLED' ||
      (!isEscrowed && deadlineAt != null && now.isAfter(deadlineAt!));

  /// Le depot necessite une redirection vers Wave plutot qu'une simple
  /// consigne de validation du code PIN.
  bool get isWaveRedirect => deposit?.authorizationUrl != null;

  /// `deadlineAt` est renvoye par le backend en `LocalDateTime` UTC, sans
  /// suffixe de zone (ex. `2026-09-08T07:30:00`). Sans ce forcage, un
  /// `DateTime.parse` classique interpreterait la chaine comme une heure
  /// locale et decalerait le compte a rebours affiche a l'expediteur.
  static DateTime? _parseUtc(String? raw) {
    if (raw == null) return null;
    final hasZone =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
    final normalized = hasZone ? raw : '${raw}Z';
    return DateTime.parse(normalized).toLocal();
  }

  @override
  List<Object?> get props => [
    bidId,
    bidStatus,
    paymentStatus,
    deadlineAt,
    amount,
    currency,
    deposit,
  ];
}
