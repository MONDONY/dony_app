import 'package:dony/features/support/data/support_attachment.dart';
import 'package:equatable/equatable.dart';

/// Statuts d'un ticket support, miroir de l'enum backend
/// `SupportTicketStatus`. Conservés en `String` côté modèle : seul
/// `RESOLVED` porte une règle métier côté app (plus d'écriture possible).
abstract final class SupportTicketStatuses {
  static const newTicket = 'NEW';
  static const assigned = 'ASSIGNED';
  static const waitingUser = 'WAITING_USER';
  static const waitingSupport = 'WAITING_SUPPORT';
  static const resolved = 'RESOLVED';
}

/// Réponse prédéfinie de l'assistant support (catalogue backend seedé).
class SupportPredefinedReply extends Equatable {
  const SupportPredefinedReply({
    required this.code,
    required this.category,
    required this.question,
    required this.answer,
  });

  final String code;
  final String category;
  final String question;
  final String answer;

  factory SupportPredefinedReply.fromJson(Map<String, dynamic> json) {
    return SupportPredefinedReply(
      code: json['code'] as String? ?? '',
      category: json['category'] as String? ?? '',
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [code, category, question, answer];
}

/// Message d'un fil de ticket. `authorType` vaut `USER` ou `ADMIN` :
/// le backend n'expose jamais l'identité de l'admin.
class SupportMessage extends Equatable {
  const SupportMessage({
    required this.id,
    required this.authorType,
    required this.content,
    this.createdAt,
    this.attachments = const [],
  });

  final String id;
  final String authorType;
  final String content;
  final DateTime? createdAt;
  final List<SupportAttachment> attachments;

  bool get isFromUser => authorType == 'USER';

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'] as List<dynamic>? ?? const [];
    return SupportMessage(
      id: json['id'] as String? ?? '',
      authorType: json['authorType'] as String? ?? 'USER',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      attachments: rawAttachments
          .map((e) => SupportAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, authorType, content, createdAt, attachments];
}

/// Ticket support. En liste, `messages` est vide (résumé backend) ;
/// le détail (`GET /support/tickets/{id}`) renvoie le fil complet.
class SupportTicket extends Equatable {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.status,
    this.createdAt,
    this.lastMessageAt,
    this.resolvedAt,
    this.messages = const [],
    this.unreadCount = 0,
    this.lastMessagePreview,
    this.lastMessageFromAdmin = false,
  });

  final String id;
  final String category;
  final String subject;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final DateTime? resolvedAt;
  final List<SupportMessage> messages;

  /// Nombre de messages non lus pour l'utilisateur courant.
  /// Vaut 0 par défaut (absent du JSON de liste ou détail).
  final int unreadCount;

  /// Aperçu du dernier message du fil (liste uniquement). Absent sur un back
  /// antérieur au contrat d'aperçu : aucune ligne d'aperçu n'est alors
  /// affichée.
  final String? lastMessagePreview;

  /// `true` quand le dernier message vient de l'équipe support.
  final bool lastMessageFromAdmin;

  bool get isResolved => status == SupportTicketStatuses.resolved;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? const [];
    return SupportTicket(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      status: json['status'] as String? ?? SupportTicketStatuses.newTicket,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
      messages: rawMessages
          .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessagePreview: _optionalString(json['lastMessagePreview']),
      lastMessageFromAdmin: json['lastMessageFromAdmin'] == true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    category,
    subject,
    status,
    createdAt,
    lastMessageAt,
    resolvedAt,
    messages,
    unreadCount,
    lastMessagePreview,
    lastMessageFromAdmin,
  ];
}

/// Dernière conversation support résumée par `GET /support/summary` : la
/// conversation non résolue la plus récente, sinon la plus récente.
class SupportSummaryTicket extends Equatable {
  const SupportSummaryTicket({
    required this.id,
    this.subject = '',
    this.lastMessagePreview,
    this.lastMessageAt,
    this.lastMessageFromAdmin = false,
    this.unreadCount = 0,
  });

  final String id;
  final String subject;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  /// `true` quand le dernier message vient de l'équipe support.
  final bool lastMessageFromAdmin;
  final int unreadCount;

  factory SupportSummaryTicket.fromJson(Map<String, dynamic> json) {
    return SupportSummaryTicket(
      id: _optionalString(json['id']) ?? '',
      subject: _optionalString(json['subject']) ?? '',
      lastMessagePreview: _optionalString(json['lastMessagePreview']),
      lastMessageAt: _optionalDate(json['lastMessageAt']),
      lastMessageFromAdmin: json['lastMessageFromAdmin'] == true,
      unreadCount: _optionalInt(json['unreadCount']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    subject,
    lastMessagePreview,
    lastMessageAt,
    lastMessageFromAdmin,
    unreadCount,
  ];
}

/// Résumé du support pour la ligne épinglée des conversations
/// (`GET /support/summary`). Lecture tolérante : un champ absent ou d'un
/// type inattendu retombe sur sa valeur neutre, jamais sur une exception.
class SupportSummary extends Equatable {
  const SupportSummary({
    required this.unreadCount,
    required this.openTicketCount,
    this.latestTicket,
  });

  /// Messages non lus, tous tickets confondus.
  final int unreadCount;

  /// Conversations non résolues.
  final int openTicketCount;

  /// Null quand l'utilisateur n'a encore aucune conversation.
  final SupportSummaryTicket? latestTicket;

  factory SupportSummary.fromJson(Map<String, dynamic> json) {
    final rawLatest = json['latestTicket'];
    final latest = rawLatest is Map
        ? SupportSummaryTicket.fromJson(Map<String, dynamic>.from(rawLatest))
        : null;
    return SupportSummary(
      unreadCount: _optionalInt(json['unreadCount']),
      openTicketCount: _optionalInt(json['openTicketCount']),
      latestTicket: latest == null || latest.id.isEmpty ? null : latest,
    );
  }

  @override
  List<Object?> get props => [unreadCount, openTicketCount, latestTicket];
}

String? _optionalString(Object? value) => value is String ? value : null;

int _optionalInt(Object? value) => value is num ? value.toInt() : 0;

DateTime? _optionalDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
