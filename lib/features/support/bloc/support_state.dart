part of 'support_bloc.dart';

enum SupportViewStatus { initial, loading, ready, failure }

enum SupportActionStatus { idle, submitting, success, failure }

/// État composite : l'écran d'accueil lit `homeStatus`/`replies`/`tickets`,
/// l'écran de détail lit `detailStatus`/`ticket`. Chaque route reçoit sa
/// propre instance de bloc (registerFactory) : les deux moitiés ne vivent
/// jamais en même temps dans le même écran.
final class SupportState extends Equatable {
  const SupportState({
    this.homeStatus = SupportViewStatus.initial,
    this.replies = const [],
    this.tickets = const [],
    this.detailStatus = SupportViewStatus.initial,
    this.ticket,
    this.createStatus = SupportActionStatus.idle,
    this.createdTicketId,
    this.sendStatus = SupportActionStatus.idle,
    this.errorMessage,
  });

  final SupportViewStatus homeStatus;
  final List<SupportPredefinedReply> replies;
  final List<SupportTicket> tickets;
  final SupportViewStatus detailStatus;
  final SupportTicket? ticket;
  final SupportActionStatus createStatus;

  /// Renseigné après une création réussie : l'écran navigue vers le détail
  /// puis le bloc de la nouvelle route recharge le fil.
  final String? createdTicketId;
  final SupportActionStatus sendStatus;
  final String? errorMessage;

  /// `createdTicketId` et `errorMessage` ne sont volontairement pas reportés
  /// de l'état précédent : ce sont des signaux à usage unique, consommés par
  /// un listener. Les reporter les rejouerait à chaque émission suivante —
  /// une erreur déjà affichée reviendrait, une navigation se déclencherait
  /// deux fois.
  SupportState copyWith({
    SupportViewStatus? homeStatus,
    List<SupportPredefinedReply>? replies,
    List<SupportTicket>? tickets,
    SupportViewStatus? detailStatus,
    SupportTicket? ticket,
    SupportActionStatus? createStatus,
    String? createdTicketId,
    SupportActionStatus? sendStatus,
    String? errorMessage,
  }) {
    return SupportState(
      homeStatus: homeStatus ?? this.homeStatus,
      replies: replies ?? this.replies,
      tickets: tickets ?? this.tickets,
      detailStatus: detailStatus ?? this.detailStatus,
      ticket: ticket ?? this.ticket,
      createStatus: createStatus ?? this.createStatus,
      createdTicketId: createdTicketId,
      sendStatus: sendStatus ?? this.sendStatus,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        homeStatus,
        replies,
        tickets,
        detailStatus,
        ticket,
        createStatus,
        createdTicketId,
        sendStatus,
        errorMessage,
      ];
}
