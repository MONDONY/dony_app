import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';

/// Le colis peut porter des frais d'annulation de l'expéditeur : frais
/// allumés côté serveur, colis CRÉÉ à la date d'effet ou après, payé en ligne
/// (carte ou mobile money, jamais espèces ni les modes historiques Wave /
/// Orange Money). Miroir de `CancellationFeeEligibility` côté back, qui reste
/// le seul juge : l'app n'en tire que le choix de ses textes (« des frais
/// peuvent s'appliquer »), jamais un montant.
///
/// Sans date de création connue (colis squelette d'un lien profond, date nulle
/// à l'époque Unix) : non couvert, les textes d'avant la fonction (le modèle
/// ne parse pas un colis sans `createdAt`).
bool isCoveredByCancellationFee(
  BidModel bid,
  CancellationFeeConfigModel config,
) {
  final from = config.effectiveFrom;
  if (!config.active || from == null) return false;
  if (bid.isSkeleton || bid.createdAt.millisecondsSinceEpoch <= 0) {
    return false;
  }
  if (_asUtc(bid.createdAt).isBefore(from)) return false;
  return bid.paymentMethod == BidPaymentMethod.stripe ||
      bid.paymentMethod == BidPaymentMethod.mobileMoney;
}

/// Le back sert `createdAt` en `LocalDateTime` UTC, sans fuseau
/// (`2026-12-15T10:00:00`), que Dart lit en heure locale : relue en UTC,
/// comme le serveur la compare à la date d'effet. Une date déjà en UTC
/// (suffixe `Z` ou décalage) reste telle quelle.
DateTime _asUtc(DateTime d) => d.isUtc
    ? d
    : DateTime.utc(
        d.year,
        d.month,
        d.day,
        d.hour,
        d.minute,
        d.second,
        d.millisecond,
        d.microsecond,
      );
