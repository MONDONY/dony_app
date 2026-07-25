import 'package:dony/core/error/app_exception.dart';

abstract class ContactRevealState {
  const ContactRevealState();
}

class ContactRevealInitial extends ContactRevealState {
  const ContactRevealInitial();
}

class ContactRevealLoading extends ContactRevealState {
  const ContactRevealLoading();
}

/// Numéro obtenu. [phoneNumber] peut être null si le compte de la contrepartie
/// n'en porte aucun : l'UI doit alors le dire, pas ouvrir un composeur vide.
class ContactRevealSuccess extends ContactRevealState {
  final String? phoneNumber;
  const ContactRevealSuccess(this.phoneNumber);
}

class ContactRevealError extends ContactRevealState {
  final AppException error;
  const ContactRevealError(this.error);
}
