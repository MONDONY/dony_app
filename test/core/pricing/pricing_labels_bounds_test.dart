import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Message d'un prix au kilo hors bornes (FLUTTER-GK), montant formaté dans la
/// devise de la saisie.
void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('trop bas : minimum formaté dans la devise, FR et EN', () {
    final xof = unitPriceBoundsError(fr, 8, SupportedCurrency.xof)!;
    expect(xof, startsWith('Prix trop bas : minimum 656'));
    expect(xof, contains('F CFA'));
    expect(xof, endsWith('/kg'));

    final eur = unitPriceBoundsError(en, 0.99, SupportedCurrency.eur)!;
    expect(eur, startsWith('Price too low: minimum'));
    expect(eur, contains('1'));
    expect(eur, endsWith('/kg'));
  });

  test('trop haut : maximum formaté dans la devise', () {
    expect(
      unitPriceBoundsError(fr, 501, SupportedCurrency.eur),
      startsWith('Prix trop élevé : maximum 500'),
    );
    expect(
      unitPriceBoundsError(en, 501, SupportedCurrency.eur),
      startsWith('Price too high: maximum'),
    );
  });

  test('dans les bornes ou non saisi : aucun message', () {
    expect(unitPriceBoundsError(fr, 656, SupportedCurrency.xof), isNull);
    expect(unitPriceBoundsError(fr, 1, SupportedCurrency.eur), isNull);
    expect(unitPriceBoundsError(fr, null, SupportedCurrency.eur), isNull);
  });
}
