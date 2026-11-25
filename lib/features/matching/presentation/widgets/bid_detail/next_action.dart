import 'package:dony/features/video_modal/data/models/parcel_role.dart';

/// Ton de la carte « prochaine action » : information (bleu) quand rien
/// d'urgent, action (orange) quand quelqu'un doit agir maintenant.
enum NextActionTone { info, action }

/// Entrée de [nextActionFor]. Les noms peuvent être vides : la carte affiche
/// alors un texte de repli.
class NextActionInput {
  const NextActionInput({
    required this.status,
    required this.role,
    this.recipientIsSender = false,
    this.travelerName = '',
    this.senderName = '',
    this.recipientName = '',
    this.arrivalCity = '',
  });

  final String status;
  final ParcelRole role;
  final bool recipientIsSender;
  final String travelerName;
  final String senderName;
  final String recipientName;
  final String arrivalCity;
}

/// Consigne à afficher : clés de texte (`nextAction*`) et arguments nommés
/// (`traveler`, `sender`, `recipient`, `city`), vides si le nom est inconnu.
class NextAction {
  const NextAction({
    required this.tone,
    required this.titleKey,
    required this.bodyKey,
    this.args = const {},
  });

  final NextActionTone tone;
  final String titleKey;
  final String bodyKey;
  final Map<String, String> args;
}

/// Prochaine action d'un colis pour un rôle, ou `null` (aucune carte) :
/// statut hors rails, destinataire avant l'arrivée, colis livré.
///
/// Le voyageur ignore [NextActionInput.recipientIsSender] : le back ne le lui
/// envoie jamais, et ses textes nomment le destinataire saisi sur le colis.
/// Le code de retrait ne figure jamais dans ces textes.
NextAction? nextActionFor(NextActionInput input) {
  final args = <String, String>{
    'traveler': input.travelerName.trim(),
    'sender': input.senderName.trim(),
    'recipient': input.recipientName.trim(),
    'city': input.arrivalCity.trim(),
  };
  NextAction make(NextActionTone tone, String title, String body) => NextAction(
    tone: tone,
    titleKey: 'nextAction${title}Title',
    bodyKey: 'nextAction${body}Body',
    args: args,
  );
  const info = NextActionTone.info;
  const action = NextActionTone.action;
  final status = input.status;

  switch (input.role) {
    case ParcelRole.sender:
      final self = input.recipientIsSender;
      return switch (status) {
        'ACCEPTED' => make(info, 'SenderAccepted', 'SenderAccepted'),
        'HANDED_OVER' || 'IN_TRANSIT' =>
          self
              ? make(info, 'SelfKeepCode', 'SelfKeepCode')
              : make(action, 'SenderCode', 'SenderCode'),
        'ARRIVED' =>
          self
              ? make(action, 'SelfWithdraw', 'SelfWithdraw')
              : make(action, 'SenderArrived', 'SenderArrived'),
        _ => null,
      };
    case ParcelRole.traveler:
      return switch (status) {
        'ACCEPTED' => make(info, 'TravelerAccepted', 'TravelerAccepted'),
        'HANDED_OVER' ||
        'IN_TRANSIT' => make(info, 'TravelerTransit', 'TravelerTransit'),
        'ARRIVED' => make(action, 'TravelerArrived', 'TravelerArrived'),
        _ => null,
      };
    case ParcelRole.recipient:
      return status == 'ARRIVED'
          ? make(action, 'RecipientArrived', 'RecipientArrived')
          : null;
  }
}
