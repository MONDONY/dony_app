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

/// Swipe-to-delete from the list: calls the API then removes locally.
class ConversationDeleteRequested extends ConversationListEvent {
  final String conversationId;
  const ConversationDeleteRequested(this.conversationId);
}

/// Silent local removal after the ChatBloc has already called the API.
class ConversationRemovedLocally extends ConversationListEvent {
  final String conversationId;
  const ConversationRemovedLocally(this.conversationId);
}
