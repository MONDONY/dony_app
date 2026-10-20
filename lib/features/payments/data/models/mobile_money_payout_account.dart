import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:equatable/equatable.dart';

/// Un compte de versement mobile money du voyageur (un par code opérateur
/// pawaPay), renvoyé par `GET/POST /payments/mobile-money/accounts`.
///
/// Le numéro n'arrive jamais en clair : [msisdnMasked] est déjà masqué par
/// le back.
class MobileMoneyPayoutAccount extends Equatable {
  const MobileMoneyPayoutAccount({
    required this.id,
    required this.provider,
    required this.providerLabel,
    required this.brand,
    required this.country,
    required this.currency,
    required this.msisdnMasked,
    this.pendingPayouts = 0,
  });

  /// Identifiant du compte. `legacy` quand il vient de l'ancien contrat
  /// (un seul compte, sans identifiant).
  final String id;

  /// Code pawaPay (`ORANGE_CIV`).
  final String provider;
  final String providerLabel;

  /// Marque du réseau (`ORANGE`) : pilote la pastille.
  final String brand;
  final String country;
  final String currency;
  final String msisdnMasked;

  /// Colis payés sur ce code qui attendent encore leur versement.
  final int pendingPayouts;

  /// Retrait et changement de numéro refusés par le back (409) tant qu'un
  /// versement attend.
  bool get isLocked => pendingPayouts > 0;

  factory MobileMoneyPayoutAccount.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as String? ?? '';
    return MobileMoneyPayoutAccount(
      id: json['id'] as String,
      provider: provider,
      providerLabel: json['providerLabel'] as String? ?? provider,
      brand: json['brand'] as String? ?? brandOf(provider),
      country: json['country'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      msisdnMasked: json['msisdnMasked'] as String? ?? '',
      pendingPayouts: (json['pendingPayouts'] as num?)?.toInt() ?? 0,
    );
  }

  /// Marque d'un code (`ORANGE_SEN` devient `ORANGE`).
  static String brandOf(String provider) {
    final i = provider.indexOf('_');
    return (i < 0 ? provider : provider.substring(0, i)).toUpperCase();
  }

  @override
  List<Object?> get props => [
    id,
    provider,
    providerLabel,
    brand,
    country,
    currency,
    msisdnMasked,
    pendingPayouts,
  ];
}

/// Liste des comptes de versement et réseaux proposés pour en ajouter.
class MobileMoneyPayoutAccounts extends Equatable {
  const MobileMoneyPayoutAccounts({
    this.accounts = const [],
    this.suggested = const [],
    this.legacy = false,
  });

  final List<MobileMoneyPayoutAccount> accounts;

  /// Réseaux suggérés pour un nouveau compte (`suggestedProviders`).
  final List<MobileMoneyProviderOption> suggested;

  /// Back sans `/accounts` : lecture de l'ancien contrat, un seul compte
  /// possible.
  final bool legacy;

  factory MobileMoneyPayoutAccounts.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    final rawSuggested = json['suggestedProviders'];
    return MobileMoneyPayoutAccounts(
      accounts: rawAccounts is List
          ? rawAccounts
                .whereType<Map<String, dynamic>>()
                .map(MobileMoneyPayoutAccount.fromJson)
                .toList()
          : const [],
      suggested: rawSuggested is List
          ? rawSuggested
                .whereType<Map<String, dynamic>>()
                .map(MobileMoneyProviderOption.fromJson)
                .toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [accounts, suggested, legacy];
}
