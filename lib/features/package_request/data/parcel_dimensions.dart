import 'package:dony/features/matching/data/models/transport_mode.dart';

/// Dimensions d'un colis (longueur, largeur, hauteur, en centimètres) et
/// volume qui en découle.
///
/// Miroir de `PackageRequestCreateRequest` (`@Min(1) @Max(400)`) et de
/// `ParcelFitRules.volumeM3` côté back : le volume affiché par l'app n'est
/// qu'un aperçu, le serveur le recalcule et ne lit jamais celui du client.
abstract final class ParcelDimensions {
  static const int minCm = 1;
  static const int maxCm = 400;

  /// Dimension valide : entière, de [minCm] à [maxCm].
  static bool isValidCm(int? cm) => cm != null && cm >= minCm && cm <= maxCm;

  /// Les trois dimensions sont renseignées et valides.
  static bool areValid(int? length, int? width, int? height) =>
      isValidCm(length) && isValidCm(width) && isValidCm(height);

  /// Une demande en bateau doit les porter (422 `boat-dimensions-required`).
  static bool isRequiredFor(TransportMode? mode) => mode == TransportMode.boat;

  /// Une demande en bateau ou « peu importe » (`null`) les garde ; pour tout
  /// autre mode le serveur les ignore et les efface, l'app ne les envoie pas.
  static bool isKeptFor(TransportMode? mode) =>
      mode == null || mode == TransportMode.boat;

  /// Volume en m³ : L × l × h / 1 000 000, arrondi à trois décimales (demi
  /// vers le haut), au minimum 0,001. `null` si une dimension manque ou sort
  /// des bornes.
  static double? volumeM3(int? length, int? width, int? height) {
    if (!areValid(length, width, height)) return null;
    final cubicCm = length! * width! * height!;
    // Millièmes de m³ : 1 000 cm³ chacun, demi vers le haut en entiers pour
    // éviter le bruit des flottants.
    final thousandths = (cubicCm + 500) ~/ 1000;
    return (thousandths < 1 ? 1 : thousandths) / 1000;
  }
}
