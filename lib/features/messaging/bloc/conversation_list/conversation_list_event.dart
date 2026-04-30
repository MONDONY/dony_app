abstract class ConversationListEvent {
  const ConversationListEvent();
}

class ConversationsLoadRequested extends ConversationListEvent {
  const ConversationsLoadRequested();
}

class ConversationsUnreadUpdated extends ConversationListEvent {
  final Map<String, int> unreadMap; // firestoreConvId → count
  const ConversationsUnreadUpdated(this.unreadMap);
}
