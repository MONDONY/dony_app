part of 'support_bloc.dart';

sealed class SupportEvent extends Equatable {
  const SupportEvent();

  @override
  List<Object?> get props => [];
}

/// Charge l'écran d'accueil support : réponses prédéfinies + tickets.
final class SupportHomeRequested extends SupportEvent {
  const SupportHomeRequested();
}

/// Crée un ticket depuis le formulaire (catégorie, sujet, premier message).
final class SupportTicketCreateRequested extends SupportEvent {
  const SupportTicketCreateRequested({
    required this.category,
    required this.subject,
    required this.message,
  });

  final String category;
  final String subject;
  final String message;

  @override
  List<Object?> get props => [category, subject, message];
}

/// Charge le détail d'un ticket (fil de messages complet).
final class SupportTicketDetailRequested extends SupportEvent {
  const SupportTicketDetailRequested(this.ticketId);

  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}

/// Envoie un message utilisateur dans le ticket courant.
final class SupportMessageSendRequested extends SupportEvent {
  const SupportMessageSendRequested({
    required this.ticketId,
    required this.content,
  });

  final String ticketId;
  final String content;

  @override
  List<Object?> get props => [ticketId, content];
}

/// Déclenche l'upload d'une image sélectionnée depuis le disque local.
/// L'upload est asynchrone : le BLoC émet d'abord `uploading`, puis
/// `ready` (avec la clé distante) ou `failed`.
final class SupportAttachmentPickRequested extends SupportEvent {
  const SupportAttachmentPickRequested(this.localPath);

  final String localPath;

  @override
  List<Object?> get props => [localPath];
}

/// Retire une image de la liste des pièces jointes en attente.
final class SupportAttachmentRemoved extends SupportEvent {
  const SupportAttachmentRemoved(this.localId);

  final String localId;

  @override
  List<Object?> get props => [localId];
}
