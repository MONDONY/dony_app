import 'package:dony/core/utils/format_volume.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/l10n/l10n.dart';

/// Volume du colis d'un trajet vendu au m³ (« 0,096 m³ »), suivi de ses
/// dimensions quand le serveur les sert et que [withDimensions] est vrai
/// (« 0,096 m³ (60 × 40 × 40 cm) »). `null` pour un colis sans volume : il
/// garde son poids.
String? bidVolumeLabel(
  AppLocalizations l,
  BidModel bid, {
  bool withDimensions = false,
}) {
  if (!bid.hasParcelVolume) return null;
  final volume = formatParcelVolumeM3(l, bid.volumeM3!);
  final (length, width, height) = (bid.lengthCm, bid.widthCm, bid.heightCm);
  if (!withDimensions || length == null || width == null || height == null) {
    return volume;
  }
  return l.requestPreviewVolumeValue(volume, length, width, height);
}

/// Taille du colis pour un résumé (billet, tuiles, listes, demandes) : son
/// volume pour un colis au m³, jamais « 0 kg » ni un tiret ; sinon son poids,
/// suivi de la taille choisie quand [withItemSize] est vrai. `null` quand ni
/// l'un ni l'autre n'est connu.
String? bidParcelSizeLabel(
  AppLocalizations l,
  BidModel bid, {
  bool withItemSize = true,
  bool withDimensions = false,
}) {
  final volume = bidVolumeLabel(l, bid, withDimensions: withDimensions);
  if (volume != null) return volume;
  final kg = bid.displayWeightKg;
  if (kg == null) return null;
  final weight = formatWeightKg(l, kg);
  return withItemSize ? parcelWeightWithSize(l, weight, bid.itemSize) : weight;
}
