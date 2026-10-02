/// Invitation « destinataire Yadony » (lot 4), vue par l'expéditeur qui l'a
/// envoyée (`GET /recipient-invitations/sent`).
///
/// La cible n'arrive que masquée. Le serveur ne distingue jamais une
/// invitation refusée, ou adressée à quelqu'un sans compte, d'une invitation
/// en attente : tout ce qui n'est pas accepté vaut `PENDING`.
class SentRecipientInvitation {
  const SentRecipientInvitation({
    required this.id,
    required this.channel,
    required this.maskedTarget,
    required this.status,
    this.createdAt,
    this.name,
  });

  factory SentRecipientInvitation.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    return SentRecipientInvitation(
      id: json['id'] as String,
      channel: json['channel'] as String? ?? 'PHONE',
      maskedTarget: json['maskedTarget'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      name: (name == null || name.isEmpty) ? null : name,
    );
  }

  final String id;

  /// `PHONE` ou `EMAIL`.
  final String channel;
  final String maskedTarget;

  /// `PENDING` ou `ACCEPTED`.
  final String status;
  final DateTime? createdAt;

  /// Nom donné par l'expéditeur à l'invitation. Absent sur un back antérieur
  /// ou quand il ne l'a pas renseigné.
  final String? name;

  bool get isAccepted => status == 'ACCEPTED';
  bool get isEmail => channel == 'EMAIL';
}

/// Invitation reçue par le titulaire du compte
/// (`GET /recipient-invitations/incoming`) : une demande en attente, ou un
/// expéditeur déjà autorisé.
class IncomingRecipientInvitation {
  const IncomingRecipientInvitation({
    required this.id,
    required this.inviterFirstName,
    required this.status,
    this.createdAt,
  });

  factory IncomingRecipientInvitation.fromJson(Map<String, dynamic> json) =>
      IncomingRecipientInvitation(
        id: json['id'] as String,
        inviterFirstName: json['inviterFirstName'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  final String id;
  final String inviterFirstName;

  /// `PENDING` ou `ACCEPTED`.
  final String status;
  final DateTime? createdAt;

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';

  IncomingRecipientInvitation copyWith({String? status}) =>
      IncomingRecipientInvitation(
        id: id,
        inviterFirstName: inviterFirstName,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
