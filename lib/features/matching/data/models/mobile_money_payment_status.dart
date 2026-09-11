import 'package:equatable/equatable.dart';

/// État d'un dépôt mobile money tenté côté pawaPay.
enum MobileMoneyDepositStatus {
  created,
  accepted,
  processing,
  completed,
  failed,
  submitRejected,
  unknown,
}

/// Dernier dépôt mobile money tenté pour un bid (nul tant qu'aucune
/// tentative n'a été faite). Fait partie de `MobileMoneyPaymentStatus`.
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
  /// plutôt que d'afficher la consigne de validation du code PIN.
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

  /// Dépôt en cours côté opérateur (PIN pas encore validé, ou en attente
  /// de confirmation Wave) : l'écran d'attente doit rester ouvert.
  bool get isLive =>
      status == MobileMoneyDepositStatus.created ||
      status == MobileMoneyDepositStatus.accepted ||
      status == MobileMoneyDepositStatus.processing;

  /// Dépôt rejeté : plus aucune action possible sans relancer un paiement.
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

/// Statut de paiement mobile money d'un bid ou d'un fil de négociation,
/// renvoyé par `POST .../mobile-money/accept`, `POST .../mobile-money/initiate`
/// et `GET .../mobile-money/status`.
class MobileMoneyPaymentStatus extends Equatable {
  const MobileMoneyPaymentStatus({
    required this.subjectId,
    this.subjectStatus,
    this.paymentStatus,
    this.deadlineAt,
    this.amount,
    this.currency = 'XOF',
    this.deposit,
  });

  /// UUID du bid ou du fil de négociation payé.
  final String subjectId;

  /// Statut du bid (`AWAITING_PAYMENT`, `ACCEPTED`, `CANCELLED`, …). Nul pour
  /// un fil de négociation : le backend n'expose pas d'équivalent, le retour
  /// à « à payer » se lit sur `paymentStatus == 'CANCELLED'`.
  final String? subjectStatus;

  /// `PENDING`, `ESCROW`, `RELEASED`, `REFUNDED`, `CANCELLED`, ou nul tant
  /// qu'aucun paiement n'a été initié.
  final String? paymentStatus;

  /// Fin de la fenêtre de 30 minutes pour payer. Renvoyée par le backend en
  /// heure locale UTC sans suffixe de zone.
  final DateTime? deadlineAt;
  final double? amount;
  final String currency;

  /// Dernier dépôt tenté, nul tant qu'aucune tentative n'a été faite.
  final MobileMoneyDeposit? deposit;

  factory MobileMoneyPaymentStatus.fromJson(Map<String, dynamic> json) =>
      MobileMoneyPaymentStatus(
        subjectId: (json['bidId'] ?? json['threadId']) as String,
        subjectStatus: json['bidStatus'] as String?,
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

  /// Paiement déjà séquestré (ou versé) : le compte à rebours ne s'applique
  /// plus et l'écran d'attente doit se refermer sur un succès.
  bool get isEscrowed =>
      paymentStatus == 'ESCROW' || paymentStatus == 'RELEASED';

  /// Un dépôt est en cours côté opérateur.
  bool get isDepositLive => deposit?.isLive ?? false;

  /// Le dernier dépôt tenté a échoué.
  bool get isDepositFailed => deposit?.isFailed ?? false;

  /// Le sujet a été annulé, le paiement du fil a été libéré (retour à
  /// « à payer », `paymentStatus == 'CANCELLED'`), ou le délai de 30 minutes
  /// est dépassé sans séquestre.
  bool isExpired(DateTime now) =>
      subjectStatus == 'CANCELLED' ||
      paymentStatus == 'CANCELLED' ||
      (!isEscrowed && deadlineAt != null && now.isAfter(deadlineAt!));

  /// Ligne de paiement libérée sans que le sujet soit annulé : le fil est
  /// revenu à « à payer » (renoncement, dépôt refusé ou échéance) et le
  /// backend accepte une nouvelle initiation. Toujours faux pour un bid, où
  /// `paymentStatus == 'CANCELLED'` n'arrive jamais sans
  /// `bidStatus == 'CANCELLED'`.
  bool get isReverted =>
      paymentStatus == 'CANCELLED' && subjectStatus != 'CANCELLED';

  /// Le dépôt nécessite une redirection vers Wave plutôt qu'une simple
  /// consigne de validation du code PIN.
  bool get isWaveRedirect => deposit?.authorizationUrl != null;

  /// `deadlineAt` est renvoyé par le backend en `LocalDateTime` UTC, sans
  /// suffixe de zone (ex. `2026-09-08T07:30:00`). Sans ce forçage, un
  /// `DateTime.parse` classique interpréterait la chaîne comme une heure
  /// locale et décalerait le compte à rebours affiché à l'expéditeur.
  static DateTime? _parseUtc(String? raw) {
    if (raw == null) return null;
    final hasZone =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
    final normalized = hasZone ? raw : '${raw}Z';
    return DateTime.parse(normalized).toLocal();
  }

  @override
  List<Object?> get props => [
    subjectId,
    subjectStatus,
    paymentStatus,
    deadlineAt,
    amount,
    currency,
    deposit,
  ];
}
