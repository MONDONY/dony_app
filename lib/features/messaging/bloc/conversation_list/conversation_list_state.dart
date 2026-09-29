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

/// Statuts d'un fil « En cours » : offre acceptée, colis remis ou en route
/// (`IN_TRANSIT`), arrivé mais pas encore livré (`TRIP_ARRIVED`). Seul
/// `BID_ACCEPTED` était retenu : le fil sortait du filtre dès la remise.
const activeBidStatuses = {'BID_ACCEPTED', 'IN_TRANSIT', 'TRIP_ARRIVED'};

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
      ConversationFilter.all => true,
      ConversationFilter.unread => c.hasUnread,
      ConversationFilter.active => activeBidStatuses.contains(c.bidStatus),
      ConversationFilter.done => c.bidStatus == 'DELIVERY_CONFIRMED',
    };
    final q = searchQuery.toLowerCase();
    final matchSearch =
        q.isEmpty ||
        c.otherParticipant.name.toLowerCase().contains(q) ||
        (c.tripOrigin?.toLowerCase().contains(q) ?? false) ||
        (c.tripDestination?.toLowerCase().contains(q) ?? false);
    return matchFilter && matchSearch;
  }).toList();

  ConversationListLoaded copyWithFilter({
    required ConversationFilter filter,
    required String searchQuery,
  }) => ConversationListLoaded(
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
