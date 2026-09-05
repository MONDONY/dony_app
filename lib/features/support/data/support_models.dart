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
  });

  final String id;
  final String authorType;
  final String content;
  final DateTime? createdAt;

  bool get isFromUser => authorType == 'USER';

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String? ?? '',
      authorType: json['authorType'] as String? ?? 'USER',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, authorType, content, createdAt];
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
  });

  final String id;
  final String category;
  final String subject;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final DateTime? resolvedAt;
  final List<SupportMessage> messages;

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
    );
  }

  @override
  List<Object?> get props =>
      [id, category, subject, status, createdAt, lastMessageAt, resolvedAt, messages];
}
