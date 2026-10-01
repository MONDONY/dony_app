import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

class ParticipantModel {
  final String id;
  final String name;
  final String? avatarUrl;

  /// L'interlocuteur est joignable (deal actif) : le bouton d'appel s'affiche.
  /// Le numéro n'est plus transmis ici ; il est demandé au tap via
  /// `GET /bids/{bidId}/contact`.
  final bool phoneAvailable;

  /// Rôle affiché en sous-titre du header, tel que servi par le back
  /// ('Voyageur' | 'Expéditeur' | 'Destinataire').
  final String? role;

  final bool kycVerified;

  const ParticipantModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.phoneAvailable = false,
    this.role,
    this.kycVerified = false,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) =>
      ParticipantModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        phoneAvailable: json['phoneAvailable'] as bool? ?? false,
        role: json['role'] as String?,
        kycVerified: json['kycVerified'] as bool? ?? false,
      );

  /// L'interlocuteur est le destinataire du colis : le back sert
  /// « Destinataire » (en dur, jamais traduit) au voyageur d'une conversation
  /// [ConversationModel.kindRecipientTraveler]. « Recipient » est aussi lu
  /// au cas où le back localiserait un jour ce libellé.
  bool get isRecipientRole {
    final value = role?.trim().toLowerCase();
    return value == 'destinataire' || value == 'recipient';
  }
}

class ConversationModel {
  final String id;
  final String bidId;
  final String firestoreConversationId;
  final ParticipantModel otherParticipant;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final bool hasUnread;
  final int unreadCount;
  // Trip metadata — populated by backend
  final String? tripOrigin;
  final String? tripDestination;
  final DateTime? tripDate;
  final double? tripWeightKg;
  // BID_ACCEPTED | DELIVERY_CONFIRMED | TRIP_CANCELLED
  final String? bidStatus;
  // True when the other party deleted: current user can read but not send
  final bool readOnly;
  // True when the current user deleted their own copy (restorable)
  final bool deletedBySelf;

  /// Type de conversation : [kindSenderTraveler] (expéditeur ↔ voyageur, une
  /// par bid) ou [kindRecipientTraveler] (voyageur ↔ destinataire rattaché,
  /// lot 3C). Un back antérieur ne sert pas le champ : c'est alors une
  /// conversation expéditeur ↔ voyageur.
  final String kind;

  static const kindSenderTraveler = 'SENDER_TRAVELER';
  static const kindRecipientTraveler = 'RECIPIENT_TRAVELER';

  /// Côté de l'utilisateur courant dans une conversation
  /// [kindRecipientTraveler] : `TRAVELER` ou `RECIPIENT`, `null` pour une
  /// conversation expéditeur ↔ voyageur ou sur un back antérieur.
  final String? viewerRole;

  static const viewerRoleTraveler = 'TRAVELER';
  static const viewerRoleRecipient = 'RECIPIENT';

  const ConversationModel({
    required this.id,
    required this.bidId,
    required this.firestoreConversationId,
    required this.otherParticipant,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.hasUnread = false,
    this.unreadCount = 0,
    this.tripOrigin,
    this.tripDestination,
    this.tripDate,
    this.tripWeightKg,
    this.bidStatus,
    this.readOnly = false,
    this.deletedBySelf = false,
    this.kind = kindSenderTraveler,
    this.viewerRole,
  });

  /// Conversation séparée voyageur ↔ destinataire : l'expéditeur n'y est pas,
  /// le numéro n'y est jamais révélé.
  bool get isRecipientConversation => kind == kindRecipientTraveler;

  /// L'utilisateur courant est le destinataire de cette conversation
  /// voyageur ↔ destinataire. [viewerRole] fait foi quand le back le sert.
  /// Sinon (back antérieur), on le déduit du rôle de l'autre participant :
  /// un interlocuteur « Destinataire » signifie que l'on est le voyageur ;
  /// tout autre rôle (« Voyageur », ou absent), que l'on est le destinataire.
  bool get viewerIsRecipient {
    if (!isRecipientConversation) return false;
    return switch (viewerRole) {
      viewerRoleRecipient => true,
      viewerRoleTraveler => false,
      _ => !otherParticipant.isRecipientRole,
    };
  }

  /// Formatted trip label for display, e.g. "Paris → Dakar · 12 jan · 5 kg"
  String? get tripLabel {
    if (tripOrigin == null || tripDestination == null) return null;
    final parts = <String>['$tripOrigin → $tripDestination'];
    if (tripDate != null) {
      parts.add(DateFormat.MMMd(AppL10n.localeName).format(tripDate!));
    }
    if (tripWeightKg != null) {
      parts.add('${tripWeightKg!.toStringAsFixed(0)} kg');
    }
    return parts.join(' · ');
  }

  ConversationModel copyWith({
    bool? hasUnread,
    int? unreadCount,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    bool? readOnly,
  }) => ConversationModel(
    id: id,
    bidId: bidId,
    firestoreConversationId: firestoreConversationId,
    otherParticipant: otherParticipant,
    lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    hasUnread: hasUnread ?? this.hasUnread,
    unreadCount: unreadCount ?? this.unreadCount,
    tripOrigin: tripOrigin,
    tripDestination: tripDestination,
    tripDate: tripDate,
    tripWeightKg: tripWeightKg,
    bidStatus: bidStatus,
    readOnly: readOnly ?? this.readOnly,
    kind: kind,
    viewerRole: viewerRole,
  );

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      ConversationModel(
        id: json['id'] as String,
        bidId: json['bidId'] as String,
        firestoreConversationId: json['firestoreConversationId'] as String,
        otherParticipant: ParticipantModel.fromJson(
          json['otherParticipant'] as Map<String, dynamic>,
        ),
        lastMessagePreview: json['lastMessagePreview'] as String?,
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.tryParse(json['lastMessageAt'] as String)
            : null,
        hasUnread: json['hasUnread'] as bool? ?? false,
        unreadCount: json['unreadCount'] as int? ?? 0,
        tripOrigin: json['tripOrigin'] as String?,
        tripDestination: json['tripDestination'] as String?,
        tripDate: json['tripDate'] != null
            ? DateTime.tryParse(json['tripDate'] as String)
            : null,
        tripWeightKg: (json['tripWeightKg'] as num?)?.toDouble(),
        bidStatus: json['bidStatus'] as String?,
        readOnly: json['readOnly'] as bool? ?? false,
        deletedBySelf: json['deletedBySelf'] as bool? ?? false,
        kind: switch (json['kind']) {
          final String value when value.trim().isNotEmpty => value.trim(),
          _ => kindSenderTraveler,
        },
        viewerRole: switch (json['viewerRole']) {
          final String value when value.trim().isNotEmpty =>
            value.trim().toUpperCase(),
          _ => null,
        },
      );
}
