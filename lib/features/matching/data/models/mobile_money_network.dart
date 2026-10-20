import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/data/payout_account_label.dart';
import 'package:equatable/equatable.dart';

/// Un réseau mobile money accepté par le voyageur d'un trajet, tel que
/// renvoyé dans `acceptedMobileMoneyNetworks` par `GET /announcements/{id}`.
///
/// Jamais de numéro : seulement l'opérateur (un compte actif du voyageur dans
/// la devise du trajet).
class MobileMoneyNetwork extends Equatable {
  const MobileMoneyNetwork({
    required this.code,
    required this.label,
    required this.brand,
    required this.country,
  });

  /// Code pawaPay (`ORANGE_CIV`).
  final String code;

  /// Libellé pawaPay (« Orange Money »), identique pour `ORANGE_CIV` et
  /// `ORANGE_SEN` : c'est le pays qui les distingue côté app.
  final String label;

  /// Marque du réseau (`ORANGE`) : pilote la pastille.
  final String brand;

  /// Code ISO 3166-1 alpha-2 (`CI`).
  final String country;

  factory MobileMoneyNetwork.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? '';
    return MobileMoneyNetwork(
      code: code,
      label: json['label'] as String? ?? code,
      brand: json['brand'] as String? ?? MobileMoneyPayoutAccount.brandOf(code),
      country: json['country'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'brand': brand,
    'country': country,
  };

  @override
  List<Object?> get props => [code, label, brand, country];
}

/// Liste `acceptedMobileMoneyNetworks` d'un trajet. Clé absente (back plus
/// ancien), non liste ou entrée illisible : liste vide, la fiche garde la
/// puce « Mobile money » d'avant.
List<MobileMoneyNetwork> mobileMoneyNetworksFromJson(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map<String, dynamic> && e['code'] is String)
        MobileMoneyNetwork.fromJson(e),
  ];
}

List<Map<String, dynamic>> mobileMoneyNetworksToJson(
  List<MobileMoneyNetwork> networks,
) => [for (final n in networks) n.toJson()];

/// Libellé de la pastille d'un réseau parmi [all] : la marque seule
/// (« Orange », « MTN »), suivie du code pays quand la même marque apparaît
/// dans deux pays (« Orange CI », « Orange SN »).
String mobileMoneyNetworkChipLabel(
  MobileMoneyNetwork n,
  List<MobileMoneyNetwork> all,
) => brandCountryLabel(
  brand: n.brand,
  country: n.country,
  fallback: brandDisplayName(n.brand),
  all: [for (final o in all) (brand: o.brand, country: o.country)],
);
