import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';

enum ConversationFilter { all, unread, active, done }

abstract class ConversationListState {
  const ConversationListState();
}

class ConversationListInitial extends ConversationListState {
  const ConversationListInitial();
}

class ConversationListLoading extends ConversationListState {
  const ConversationListLoading();
}

class ConversationListLoaded extends ConversationListState {
  final List<ConversationModel> conversations;
  final List<ConversationModel> archivedConversations;
  final ConversationFilter filter;
  final String searchQuery;

  const ConversationListLoaded(
    this.conversations, {
    this.archivedConversations = const [],
    this.filter = ConversationFilter.all,
    this.searchQuery = '',
  });

  /// Liste filtrée + recherche — calculée à chaque build, sans duplication.
  List<ConversationModel> get displayed => conversations.where((c) {
        final matchFilter = switch (filter) {
          ConversationFilter.all    => true,
          ConversationFilter.unread => c.hasUnread,
          ConversationFilter.active => c.bidStatus == 'BID_ACCEPTED',
          ConversationFilter.done   => c.bidStatus == 'DELIVERY_CONFIRMED',
        };
        final q = searchQuery.toLowerCase();
        final matchSearch = q.isEmpty ||
            c.otherParticipant.name.toLowerCase().contains(q) ||
            (c.tripOrigin?.toLowerCase().contains(q) ?? false) ||
            (c.tripDestination?.toLowerCase().contains(q) ?? false);
        return matchFilter && matchSearch;
      }).toList();

  ConversationListLoaded copyWithFilter({
    required ConversationFilter filter,
    required String searchQuery,
  }) =>
      ConversationListLoaded(
        conversations,
        archivedConversations: archivedConversations,
        filter: filter,
        searchQuery: searchQuery,
      );
}

class ConversationListError extends ConversationListState {
  final AppException error;
  const ConversationListError(this.error);
}
