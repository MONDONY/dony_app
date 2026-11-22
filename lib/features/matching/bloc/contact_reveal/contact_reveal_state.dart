import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/phone/phone_verification_level.dart';

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

  /// Fiabilité du numéro : SMS, Yadony, ou aucune (numéro seulement déclaré).
  final PhoneVerificationLevel verification;
  const ContactRevealSuccess(
    this.phoneNumber, {
    this.verification = PhoneVerificationLevel.sms,
  });
}

class ContactRevealError extends ContactRevealState {
  final AppException error;
  const ContactRevealError(this.error);
}
