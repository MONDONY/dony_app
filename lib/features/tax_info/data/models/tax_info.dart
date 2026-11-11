import 'package:equatable/equatable.dart';

/// Faut-il demander ses informations fiscales à ce voyageur ? Miroir de
/// `solicitation` côté back (`TaxInfoResponse`, lot 3a DAC7).
///
/// Seul [solliciter] ouvre une bannière. Une valeur inconnue ou absente (back
/// plus récent) tombe sur [nePasSolliciter] : dans le doute, on ne demande rien.
enum TaxInfoSolicitation {
  solliciter('SOLLICITER'),
  dejaFourni('DEJA_FOURNI'),
  nePasSolliciter('NE_PAS_SOLLICITER');

  const TaxInfoSolicitation(this.wire);

  final String wire;

  static TaxInfoSolicitation fromWire(String? value) =>
      TaxInfoSolicitation.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => TaxInfoSolicitation.nePasSolliciter,
      );
}

/// Réponse de `GET` et `PUT /travelers/me/tax-info`.
///
/// Le numéro fiscal et la TVA ne reviennent jamais en clair : seules leurs
/// formes masquées (« ****1234 ») sont affichables.
class TaxInfo extends Equatable {
  const TaxInfo({
    required this.provided,
    required this.solicitation,
    this.maskedTaxIdentificationNumber,
    this.taxCountry,
    this.vatNumberProvided = false,
    this.maskedVatNumber,
    this.providedAt,
    this.residenceCountry,
    this.dac7Status,
  });

  factory TaxInfo.fromJson(Map<String, dynamic> json) => TaxInfo(
    provided: json['provided'] == true,
    maskedTaxIdentificationNumber: _text(json['maskedTaxIdentificationNumber']),
    taxCountry: _text(json['taxCountry']),
    vatNumberProvided: json['vatNumberProvided'] == true,
    maskedVatNumber: _text(json['maskedVatNumber']),
    providedAt: DateTime.tryParse(json['providedAt'] as String? ?? ''),
    residenceCountry: _text(json['residenceCountry']),
    dac7Status: _text(json['dac7Status']),
    solicitation: TaxInfoSolicitation.fromWire(json['solicitation'] as String?),
  );

  final bool provided;
  final String? maskedTaxIdentificationNumber;

  /// Pays d'émission du numéro (ISO 3166-1 alpha-2).
  final String? taxCountry;
  final bool vatNumberProvided;
  final String? maskedVatNumber;
  final DateTime? providedAt;
  final String? residenceCountry;

  /// `DECLARABLE`, `NON_DECLARABLE` ou `RESIDENCE_INCONNUE` ; non interprété
  /// par l'app, l'écran ne s'en sert pas.
  final String? dac7Status;
  final TaxInfoSolicitation solicitation;

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
    provided,
    maskedTaxIdentificationNumber,
    taxCountry,
    vatNumberProvided,
    maskedVatNumber,
    providedAt,
    residenceCountry,
    dac7Status,
    solicitation,
  ];
}
