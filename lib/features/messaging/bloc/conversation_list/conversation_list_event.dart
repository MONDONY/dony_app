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

/// Volet glissant « Sourdine » / « Réactiver » : bascule optimiste des
/// notifications du fil, annulée si le serveur refuse (FLUTTER-CM).
class ConversationNotificationsMuteToggled extends ConversationListEvent {
  final String conversationId;
  const ConversationNotificationsMuteToggled(this.conversationId);
}

/// Bascule faite depuis l'écran de chat, qui a déjà appelé l'API : la liste
/// reflète l'état sans nouvel appel.
class ConversationNotificationsMuteSynced extends ConversationListEvent {
  final String conversationId;
  final bool muted;
  const ConversationNotificationsMuteSynced(
    this.conversationId, {
    required this.muted,
  });
}

/// Sélection multiple (FLUTTER-M4) : archive le lot. Retrait optimiste des
/// fils, remis en place pour ceux que le serveur refuse ; le retour arrive
/// dans [ConversationListLoaded.batchFeedback].
class ConversationsBatchArchiveRequested extends ConversationListEvent {
  final List<String> conversationIds;
  const ConversationsBatchArchiveRequested(this.conversationIds);
}

/// Désarchive le lot : depuis l'écran des archives, ou « Annuler » après un
/// archivage groupé.
class ConversationsBatchUnarchiveRequested extends ConversationListEvent {
  final List<String> conversationIds;

  /// `true` pour l'« Annuler » d'un archivage groupé : aucune snackbar de
  /// confirmation ne suit, seulement un éventuel échec.
  final bool isUndo;
  const ConversationsBatchUnarchiveRequested(
    this.conversationIds, {
    this.isUndo = false,
  });
}

/// Supprime le lot (après confirmation dans l'écran).
class ConversationsBatchDeleteRequested extends ConversationListEvent {
  final List<String> conversationIds;
  const ConversationsBatchDeleteRequested(this.conversationIds);
}
