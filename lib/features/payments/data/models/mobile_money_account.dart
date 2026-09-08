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
    this.providerLabel,
    this.country,
    this.currency,
  });

  final MobileMoneyAccountStatus status;
  final String? msisdnMasked;
  final String? providerLabel;
  final String? country;
  final String? currency;

  factory MobileMoneyAccount.fromJson(Map<String, dynamic> json) =>
      MobileMoneyAccount(
        status: _statusFromJson(json['status'] as String?),
        msisdnMasked: json['msisdnMasked'] as String?,
        providerLabel: json['providerLabel'] as String?,
        country: json['country'] as String?,
        currency: json['currency'] as String?,
      );

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
    providerLabel,
    country,
    currency,
  ];
}
