import 'package:equatable/equatable.dart';

/// Opérateurs mobile money que le voyageur accepte pour un colis (ou un
/// fil, ou un supplément), renvoyés par
/// `GET …/mobile-money/accepted-operators`. L'expéditeur choisit ensuite son
/// propre opérateur dans le catalogue du pays ; ce modèle sert à lui dire
/// lesquels le voyageur accepte.
class MobileMoneyAcceptedOperators extends Equatable {
  const MobileMoneyAcceptedOperators({
    this.currency,
    this.travelerFirstName,
    this.providers = const {},
  });

  /// Devise du paiement (`XOF`, `XAF`...), nulle si le back ne la précise pas.
  final String? currency;

  /// Prénom du voyageur, pour les textes (« Awa accepte… »).
  final String? travelerFirstName;

  /// Codes pawaPay acceptés (`ORANGE_CIV`, `MTN_MOMO_CIV`...). Vide quand le
  /// back n'en renvoie aucun.
  final Set<String> providers;

  factory MobileMoneyAcceptedOperators.fromJson(Map<String, dynamic> json) =>
      MobileMoneyAcceptedOperators(
        currency: json['currency'] as String?,
        travelerFirstName: json['travelerFirstName'] as String?,
        providers: {
          for (final p in (json['providers'] as List<dynamic>? ?? const []))
            p as String,
        },
      );

  @override
  List<Object?> get props => [currency, travelerFirstName, providers];
}
