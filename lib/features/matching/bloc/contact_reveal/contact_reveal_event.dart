abstract class ContactRevealEvent {
  const ContactRevealEvent();
}

/// L'utilisateur a appuyé sur « appeler » : on demande le numéro au serveur.
class ContactRevealRequested extends ContactRevealEvent {
  final String bidId;
  const ContactRevealRequested(this.bidId);
}
