import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';

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

/// Pill de filtre ou saisie dans le champ de recherche.
class ConversationFilterChanged extends ConversationListEvent {
  final ConversationFilter filter;
  final String searchQuery;
  const ConversationFilterChanged({
    required this.filter,
    required this.searchQuery,
  });
}

/// Swipe-to-archive : déplace vers la liste archivée sans appel API.
class ConversationArchiveRequested extends ConversationListEvent {
  final String conversationId;
  const ConversationArchiveRequested(this.conversationId);
}

/// Désarchiver : remet la conversation dans la liste principale.
class ConversationUnarchiveRequested extends ConversationListEvent {
  final String conversationId;
  const ConversationUnarchiveRequested(this.conversationId);
}
