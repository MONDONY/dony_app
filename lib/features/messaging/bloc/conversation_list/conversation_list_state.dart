import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';

/// Filtres de Messages (YADONY-FLUTTER-PROD-W) : « Tous » et « Non lus » ont
/// disparu. [active] (par défaut) garde tout fil encore utile : colis pas
/// terminé, ou message pas encore lu. [done] range les fils terminés (colis
/// livré ou annulé, [ConversationModel.isFinished]) une fois lus.
enum ConversationFilter {
  active,
  done;

  bool matches(ConversationModel c) => switch (this) {
    ConversationFilter.active => !c.isFinished || c.hasUnread,
    ConversationFilter.done => c.isFinished && !c.hasUnread,
  };
}

abstract class ConversationListState {
  const ConversationListState();
}

class ConversationListInitial extends ConversationListState {
  const ConversationListInitial();
}

class ConversationListLoading extends ConversationListState {
  const ConversationListLoading();
}

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
    this.filter = ConversationFilter.active,
    this.searchQuery = '',
    this.muteFeedback,
    this.batchFeedback,
  });

  /// Liste filtrée + recherche — calculée à chaque build, sans duplication.
  List<ConversationModel> get displayed => conversations.where((c) {
    final matchFilter = filter.matches(c);
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
