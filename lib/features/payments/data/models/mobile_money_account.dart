import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:equatable/equatable.dart';

/// État du compte de versement mobile money d'un voyageur.
enum MobileMoneyAccountStatus { notConfigured, active, disabled }

/// Compte de versement mobile money (voyageur), renvoyé par
/// `GET/POST/DELETE /payments/mobile-money/account`.
///
/// Le numéro de téléphone n'est jamais exposé en clair : `msisdnMasked`
/// est déjà masqué côté backend.
class MobileMoneyAccount extends Equatable {
  const MobileMoneyAccount({
    required this.status,
    this.msisdnMasked,
    this.provider,
    this.providerLabel,
    this.country,
    this.currency,
    this.providers = const [],
  });

  final MobileMoneyAccountStatus status;
  final String? msisdnMasked;

  /// Code pawaPay du réseau de repli du versement (`ORANGE_CIV`).
  final String? provider;
  final String? providerLabel;
  final String? country;
  final String? currency;

  /// Réseaux acceptés. Ancien contrat sans liste : repli sur [provider].
  final List<MobileMoneyProviderOption> providers;

  factory MobileMoneyAccount.fromJson(Map<String, dynamic> json) =>
      MobileMoneyAccount(
        status: _statusFromJson(json['status'] as String?),
        msisdnMasked: json['msisdnMasked'] as String?,
        provider: json['provider'] as String?,
        providerLabel: json['providerLabel'] as String?,
        country: json['country'] as String?,
        currency: json['currency'] as String?,
        providers: _providersFromJson(json),
      );

  static List<MobileMoneyProviderOption> _providersFromJson(
    Map<String, dynamic> json,
  ) {
    final raw = json['providers'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MobileMoneyProviderOption.fromJson)
          .toList();
    }
    final code = json['provider'] as String?;
    if (code == null) return const [];
    return [
      MobileMoneyProviderOption(
        code: code,
        label: json['providerLabel'] as String? ?? code,
      ),
    ];
  }

  /// Compte actif : le voyageur peut recevoir des versements mobile money.
  bool get isActive => status == MobileMoneyAccountStatus.active;

  static MobileMoneyAccountStatus _statusFromJson(String? raw) {
    switch (raw) {
      case 'ACTIVE':
        return MobileMoneyAccountStatus.active;
      case 'DISABLED':
        return MobileMoneyAccountStatus.disabled;
      case 'NOT_CONFIGURED':
      default:
        return MobileMoneyAccountStatus.notConfigured;
    }
  }

  @override
  List<Object?> get props => [
    status,
    msisdnMasked,
    provider,
    providerLabel,
    country,
    currency,
    providers,
  ];
}
