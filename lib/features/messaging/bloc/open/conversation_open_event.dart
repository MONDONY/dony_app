abstract class ConversationOpenEvent {
  const ConversationOpenEvent();
}

class ConversationOpenRequested extends ConversationOpenEvent {
  final String bidId;
  const ConversationOpenRequested(this.bidId);
}

/// Côté depuis lequel une conversation voyageur ↔ destinataire est ouverte.
/// Sa valeur `name` part telle quelle dans l'analytics (`role`).
enum RecipientConversationRole { traveler, recipient }

/// Ouvre (ou crée) la conversation séparée voyageur ↔ destinataire du bid
/// (lot 3C), `GET /conversations/bid/{bidId}/recipient`.
class RecipientConversationOpenRequested extends ConversationOpenEvent {
  final String bidId;
  final RecipientConversationRole role;
  const RecipientConversationOpenRequested(this.bidId, {required this.role});
}
