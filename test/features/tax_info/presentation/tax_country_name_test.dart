import 'package:dony/features/tax_info/presentation/widgets/tax_info_labels.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les pays de l'Union absents du catalogue de l'app ne sont nommés que pour
/// les informations fiscales : ils ne doivent rien changer aux autres écrans
/// (adresses de retrait, livraison, Réglages), qui s'appuient sur
/// [countryName] et [knownCountryCode].
void main() {
  const extra = ['BG', 'CZ', 'DK', 'HU', 'PL', 'RO', 'SE'];
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  test('nommés pour le fiscal, en FR et en EN', () {
    expect(taxCountryName(fr, 'SE'), 'Suède');
    expect(taxCountryName(en, 'SE'), 'Sweden');
    expect(taxCountryName(fr, 'PL'), 'Pologne');
    for (final code in extra) {
      expect(taxCountryName(fr, code), isNot(code), reason: code);
      expect(taxCountryName(en, code), isNot(code), reason: code);
    }
    // Les autres pays : le nom partagé.
    expect(taxCountryName(fr, 'FR'), countryName(fr, 'FR'));
    expect(taxCountryName(fr, 'ZZ'), 'ZZ');
  });

  test('toujours inconnus des écrans d\'adresses', () {
    for (final code in extra) {
      expect(countryName(fr, code), code, reason: code);
      expect(knownCountryCode(fr, code), isNull, reason: code);
    }
  });
}
