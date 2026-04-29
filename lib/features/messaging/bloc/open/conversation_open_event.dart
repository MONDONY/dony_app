abstract class ConversationOpenEvent {
  const ConversationOpenEvent();
}

class ConversationOpenRequested extends ConversationOpenEvent {
  final String bidId;
  const ConversationOpenRequested(this.bidId);
}
