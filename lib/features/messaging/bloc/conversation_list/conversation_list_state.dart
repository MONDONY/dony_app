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

/// Retour ponctuel d'une bascule de sourdine lancée depuis la liste :
/// confirmation ([error] `null`) ou échec, la bascule étant alors annulée.
class ConversationMuteFeedback {
  /// État demandé par l'utilisateur (`true` = sourdine).
  final bool muted;
  final AppException? error;
  const ConversationMuteFeedback({required this.muted, this.error});
}

/// Action groupée de la sélection multiple.
enum ConversationBatchAction { archive, unarchive, delete }

/// Retour ponctuel d'une action groupée, porté par la seule émission qui suit
/// la réponse du serveur : l'écran l'affiche une fois en snackbar.
class ConversationBatchFeedback {
  final ConversationBatchAction action;

  /// Ids traités par le serveur (cible de l'« Annuler » d'un archivage).
  final List<String> succeededIds;

  /// Nombre de fils refusés ou en échec, remis dans leur liste.
  final int failedCount;

  /// Erreur globale (réseau, serveur) : rien n'a été traité.
  final AppException? error;

  /// « Annuler » d'un archivage : pas de snackbar de confirmation.
  final bool isUndo;

  const ConversationBatchFeedback({
    required this.action,
    this.succeededIds = const [],
    this.failedCount = 0,
    this.error,
    this.isUndo = false,
  });
}

class ConversationListLoaded extends ConversationListState {
  final List<ConversationModel> conversations;
  final List<ConversationModel> archivedConversations;
  final ConversationFilter filter;
  final String searchQuery;

  /// Porté par la seule émission qui suit la réponse du serveur, `null`
  /// ensuite : l'écran l'affiche une fois en snackbar.
  final ConversationMuteFeedback? muteFeedback;

  /// Même règle que [muteFeedback] pour les actions groupées.
  final ConversationBatchFeedback? batchFeedback;

  const ConversationListLoaded(
    this.conversations, {
    this.archivedConversations = const [],
    this.filter = ConversationFilter.all,
    this.searchQuery = '',
    this.muteFeedback,
    this.batchFeedback,
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
