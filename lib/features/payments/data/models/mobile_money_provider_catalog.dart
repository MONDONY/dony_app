import 'package:equatable/equatable.dart';

/// Un réseau mobile money utilisable sur un numéro, tel que renvoyé par
/// `POST /payments/mobile-money/providers` (voyageur) et
/// `POST /bids/{id}/mobile-money/providers` (payeur).
class MobileMoneyProviderOption extends Equatable {
  const MobileMoneyProviderOption({
    required this.code,
    required this.label,
    this.detected = false,
  });

  /// Code pawaPay (`ORANGE_CIV`, `WAVE_SEN`...).
  final String code;

  /// Libellé lisible (« Orange Money », « Wave »).
  final String label;

  /// Opérateur prédit par pawaPay pour ce numéro : pré-coché dans l'app.
  final bool detected;

  factory MobileMoneyProviderOption.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    return MobileMoneyProviderOption(
      code: code,
      label: json['label'] as String? ?? code,
      detected: json['detected'] as bool? ?? false,
    );
  }

  /// Marque du code (`ORANGE_SEN` → `ORANGE`) : pilote la pastille.
  String get brand {
    final i = code.indexOf('_');
    return (i < 0 ? code : code.substring(0, i)).toUpperCase();
  }

  @override
  List<Object?> get props => [code, label, detected];
}

/// Catalogue des réseaux d'un numéro. Côté payeur, `travelerAccepts` et
/// `travelerFirstName` décrivent le voyageur ; côté voyageur ils sont vides.
///
/// Le numéro n'est jamais reçu en clair : seulement `msisdnMasked`.
class MobileMoneyProviderCatalog extends Equatable {
  const MobileMoneyProviderCatalog({
    this.country,
    this.currency,
    this.msisdnMasked,
    this.detected,
    this.providers = const [],
    this.travelerAccepts = const [],
    this.travelerFirstName,
  });

  final String? country;
  final String? currency;
  final String? msisdnMasked;

  /// Code de l'opérateur prédit s'il figure dans [providers], sinon nul.
  final String? detected;
  final List<MobileMoneyProviderOption> providers;

  /// Libellés des réseaux acceptés par le voyageur (côté payeur).
  final List<String> travelerAccepts;
  final String? travelerFirstName;

  factory MobileMoneyProviderCatalog.fromJson(Map<String, dynamic> json) =>
      MobileMoneyProviderCatalog(
        country: json['country'] as String?,
        currency: json['currency'] as String?,
        msisdnMasked: json['msisdnMasked'] as String?,
        detected: json['detected'] as String?,
        providers: (json['providers'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MobileMoneyProviderOption.fromJson)
            .toList(),
        travelerAccepts: (json['travelerAccepts'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        travelerFirstName: json['travelerFirstName'] as String?,
      );

  bool get isEmpty => providers.isEmpty;

  /// Option prédite, si elle figure dans la liste.
  MobileMoneyProviderOption? get detectedOption {
    for (final p in providers) {
      if (p.detected) return p;
    }
    return null;
  }

  /// Codes de [selected] dans l'ordre du catalogue : c'est cet ordre que le
  /// back enregistre.
  List<String> ordered(Set<String> selected) =>
      providers.map((p) => p.code).where(selected.contains).toList();

  @override
  List<Object?> get props => [
    country,
    currency,
    msisdnMasked,
    detected,
    providers,
    travelerAccepts,
    travelerFirstName,
  ];
}
