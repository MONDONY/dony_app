import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Outillage de mesure du contraste, partagé par les tests d'accessibilité.
///
/// Volontairement dans `test/` et non dans `lib/` : c'est un instrument de
/// vérification, il n'a rien à faire dans le binaire livré.

/// Luminance relative, formule WCAG 2.1.
double luminance(Color c) {
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

/// Ratio de contraste entre deux couleurs opaques, de 1:1 à 21:1.
double contrastRatio(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  final haut = math.max(la, lb);
  final bas = math.min(la, lb);
  return (haut + 0.05) / (bas + 0.05);
}

/// Échoue en affichant le ratio mesuré.
///
/// Sans cela, un écart de 0.01 se lit « false » et oblige à recalculer à la
/// main pour savoir de combien on a manqué le seuil.
void expectContrast(Color fg, Color bg, double min, String label) {
  final r = contrastRatio(fg, bg);
  expect(
    r,
    greaterThanOrEqualTo(min),
    reason: '$label : ${r.toStringAsFixed(2)}:1, minimum requis $min:1',
  );
}

/// Seuils WCAG 2.1 utilisés dans les tests.
abstract final class Seuil {
  /// Texte courant, critère 1.4.3.
  static const double texte = 4.5;

  /// Texte large et éléments d'interface, critères 1.4.3 et 1.4.11.
  static const double grand = 3.0;

  /// Cible que s'impose la variante haut contraste, au-delà de l'exigence AA.
  static const double hautContraste = 7.0;
}
