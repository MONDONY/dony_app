import 'package:equatable/equatable.dart';

/// Clé éphémère Stripe (POST /payments/me/ephemeral-key) : permet au SDK
/// natif d'afficher/gérer les moyens de paiement du customer dans la
/// PaymentSheet Stripe sans jamais exposer la clé secrète du compte.
class EphemeralKeyModel extends Equatable {
  final String ephemeralKeySecret;
  final String customerId;

  const EphemeralKeyModel({
    required this.ephemeralKeySecret,
    required this.customerId,
  });

  factory EphemeralKeyModel.fromJson(Map<String, dynamic> json) =>
      EphemeralKeyModel(
        ephemeralKeySecret: json['ephemeralKeySecret'] as String,
        customerId: json['customerId'] as String,
      );

  @override
  List<Object?> get props => [ephemeralKeySecret, customerId];
}
