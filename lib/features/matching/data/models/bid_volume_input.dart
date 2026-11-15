import 'package:dony/features/package_request/data/parcel_dimensions.dart';
import 'package:equatable/equatable.dart';

/// Dimensions du colis d'une réservation sur un trajet vendu au m³ (bateau),
/// en centimètres, entiers de 1 à 400.
///
/// Le volume n'est qu'un aperçu pour l'écran : le serveur le recalcule à
/// partir des trois dimensions et ne lit jamais celui du client.
class BidVolumeInput extends Equatable {
  const BidVolumeInput({
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
  });

  final int lengthCm;
  final int widthCm;
  final int heightCm;

  /// `null` tant que l'une des trois dimensions manque ou sort des bornes.
  static BidVolumeInput? tryCreate(int? length, int? width, int? height) =>
      ParcelDimensions.areValid(length, width, height)
      ? BidVolumeInput(lengthCm: length!, widthCm: width!, heightCm: height!)
      : null;

  /// Volume en m³ (L × l × h / 1 000 000, trois décimales), même règle que le
  /// serveur.
  double get volumeM3 =>
      ParcelDimensions.volumeM3(lengthCm, widthCm, heightCm)!;

  @override
  List<Object?> get props => [lengthCm, widthCm, heightCm];
}
