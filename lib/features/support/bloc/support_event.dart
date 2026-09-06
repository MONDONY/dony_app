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
