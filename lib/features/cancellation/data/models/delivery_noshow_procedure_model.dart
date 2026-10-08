/// État de la procédure « destinataire absent » d'un colis (FLUTTER-E2),
/// servi par `GET /cancellations/bids/{id}/delivery-noshow` (yadony-back,
/// PR jumelle). Tous les champs sont optionnels à la lecture : l'app tolère
/// un back plus ancien ou plus récent.
class DeliveryNoShowProcedureModel {
  const DeliveryNoShowProcedureModel({
    required this.bidId,
    required this.role,
    required this.bidStatus,
    this.arrivedAt,
    this.reportAvailableAt,
    this.waitElapsed = false,
    this.contactProof,
    this.canReport = false,
    this.reported = false,
    this.noShowStatus,
    this.contestationDeadline,
    this.holdUntil,
    this.retryAppointmentAt,
    this.retryAppointmentNote,
    this.unclaimedAt,
    this.canSetRetryAppointment = false,
    this.minWaitMinutes = 120,
    this.holdDays = 7,
  });

  factory DeliveryNoShowProcedureModel.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final raw = json[key];
      return raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    }

    return DeliveryNoShowProcedureModel(
      bidId: json['bidId'] as String? ?? '',
      role: json['role'] as String? ?? 'TRAVELER',
      bidStatus: json['bidStatus'] as String? ?? '',
      arrivedAt: date('arrivedAt'),
      reportAvailableAt: date('reportAvailableAt'),
      waitElapsed: json['waitElapsed'] as bool? ?? false,
      contactProof: json['contactProof'] as String?,
      canReport: json['canReport'] as bool? ?? false,
      reported: json['reported'] as bool? ?? false,
      noShowStatus: json['noShowStatus'] as String?,
      contestationDeadline: date('contestationDeadline'),
      holdUntil: date('holdUntil'),
      retryAppointmentAt: date('retryAppointmentAt'),
      retryAppointmentNote: json['retryAppointmentNote'] as String?,
      unclaimedAt: date('unclaimedAt'),
      canSetRetryAppointment: json['canSetRetryAppointment'] as bool? ?? false,
      minWaitMinutes: (json['minWaitMinutes'] as num?)?.toInt() ?? 120,
      holdDays: (json['holdDays'] as num?)?.toInt() ?? 7,
    );
  }

  final String bidId;

  /// `SENDER` ou `TRAVELER` : le rôle de l'utilisateur sur ce colis.
  final String role;
  final String bidStatus;
  final DateTime? arrivedAt;

  /// Heure à partir de laquelle le voyageur peut signaler l'absence.
  final DateTime? reportAvailableAt;
  final bool waitElapsed;

  /// `CALL` ou `MESSAGE` : tentative de contact vue par le serveur.
  final String? contactProof;
  final bool canReport;
  final bool reported;
  final String? noShowStatus;
  final DateTime? contestationDeadline;

  /// Fin de la garde du colis par le voyageur.
  final DateTime? holdUntil;
  final DateTime? retryAppointmentAt;
  final String? retryAppointmentNote;

  /// Colis passé « non réclamé » (garde échue, voyageur payé).
  final DateTime? unclaimedAt;
  final bool canSetRetryAppointment;
  final int minWaitMinutes;
  final int holdDays;

  bool get isSender => role == 'SENDER';
  bool get isUnclaimed => unclaimedAt != null;
  bool get hasContactProof => contactProof != null;

  /// La garde est en cours : signalement fait avec la procédure, colis pas
  /// encore « non réclamé ».
  bool get isHolding => reported && holdUntil != null && !isUnclaimed;
}
