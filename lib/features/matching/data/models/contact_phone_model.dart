import 'package:dony/core/phone/phone_verification_level.dart';
import 'package:equatable/equatable.dart';

/// Numéro de la contrepartie (`GET /bids/{id}/contact`) et ce qu'on sait de sa
/// fiabilité : [phoneNumber] est celui vérifié par SMS, sinon le numéro déclaré.
class ContactPhoneModel extends Equatable {
  const ContactPhoneModel({
    this.phoneNumber,
    this.verification = PhoneVerificationLevel.sms,
  });

  /// `null` si le compte n'a aucun numéro.
  final String? phoneNumber;

  /// Un back antérieur n'envoie pas `verification` : numéro vérifié par SMS.
  final PhoneVerificationLevel verification;

  factory ContactPhoneModel.fromJson(Map<String, dynamic> json) =>
      ContactPhoneModel(
        phoneNumber: json['phoneNumber'] as String?,
        verification: PhoneVerificationLevel.parseContact(
          json['verification'] as String?,
        ),
      );

  @override
  List<Object?> get props => [phoneNumber, verification];
}
