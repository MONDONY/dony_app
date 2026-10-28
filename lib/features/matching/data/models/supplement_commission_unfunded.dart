import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/commission_funding_alternative.dart';
import 'package:dony/features/matching/data/models/commission_funding_detail.dart';
import 'package:dony/features/matching/data/models/commission_shortfall.dart';
import 'package:equatable/equatable.dart';

/// 422 `supplement-commission-unfunded` d'une demande de supplément sur un
/// colis payé en espèces : le solde du voyageur ne couvre pas la commission
/// du supplément. Rien n'a été créé ni débité. Mêmes champs que le « solde
/// insuffisant » de l'acceptation d'un colis en espèces, plus [shortfall].
class SupplementCommissionUnfunded extends Equatable {
  const SupplementCommissionUnfunded({
    required this.availableBalance,
    required this.requiredCommission,
    required this.shortfall,
    required this.hasCard,
    this.currency,
    this.breakdown,
    this.bidCurrency,
    this.alternatives = const [],
    this.fundingDetail,
  });

  static const code = 'supplement-commission-unfunded';

  /// Même refus, même corps, pour la commission d'une modification de colis.
  static const amendmentCode = 'amendment-commission-unfunded';

  /// Solde du portefeuille de complément ([currency]).
  final double availableBalance;

  /// Commission exprimée dans [currency].
  final double requiredCommission;

  /// Ce qui manque, dans [currency].
  final double shortfall;

  /// Une carte commission est enregistrée : « Payer par carte » possible.
  final bool hasCard;

  /// Devise de complément (code ISO).
  final String? currency;

  /// Détail quand la devise du colis diffère de celle du complément.
  final CommissionShortfall? breakdown;

  /// Devise du colis.
  final String? bidCurrency;

  /// Autres portefeuilles capables de couvrir le reste au taux du jour.
  final List<CommissionFundingAlternative> alternatives;

  /// Détail par portefeuille (somme de toutes les devises), absent avec un
  /// ancien back.
  final CommissionFundingDetail? fundingDetail;

  /// Lit le refus depuis l'erreur rendue par l'API ; `null` pour toute autre
  /// erreur. Tolérant : un champ absent ou mal formé prend une valeur neutre.
  static SupplementCommissionUnfunded? fromError(AppException error) {
    if (error is! ValidationException ||
        (error.code != code && error.code != amendmentCode)) {
      return null;
    }
    final ext = error.extensions ?? const <String, Object?>{};
    double num0(String key) => (ext[key] as num?)?.toDouble() ?? 0;
    final rawBreakdown = ext['breakdown'];
    CommissionShortfall? breakdown;
    if (rawBreakdown is Map) {
      try {
        breakdown = CommissionShortfall.fromJson(
          Map<String, dynamic>.from(rawBreakdown),
        );
      } catch (_) {
        breakdown = null;
      }
    }
    final currency = ext['currency'];
    final bidCurrency = ext['bidCurrency'];
    return SupplementCommissionUnfunded(
      availableBalance: num0('availableBalance'),
      requiredCommission: num0('requiredCommission'),
      shortfall: num0('shortfall'),
      hasCard: ext['hasCard'] == true,
      currency: currency is String ? currency.toUpperCase() : null,
      breakdown: breakdown,
      bidCurrency: bidCurrency is String ? bidCurrency.toUpperCase() : null,
      alternatives: CommissionFundingAlternative.listFromJson(
        ext['alternatives'],
      ),
      fundingDetail: CommissionFundingDetail.tryParse(ext['fundingDetail']),
    );
  }

  @override
  List<Object?> get props => [
    availableBalance,
    requiredCommission,
    shortfall,
    hasCard,
    currency,
    breakdown,
    bidCurrency,
    alternatives,
    fundingDetail,
  ];
}
