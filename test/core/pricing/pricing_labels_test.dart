import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('commissionPercentLabel', () {
    tearDown(() => setDonyCommissionRate(kDonyCommissionRateDefault));

    test('taux entier → entier sans décimale, fr et en identiques', () {
      setDonyCommissionRate(0.12);
      expect(commissionPercentLabel(fr), '12');
      expect(commissionPercentLabel(en), '12');
    });

    test('taux décimal → une décimale à la langue', () {
      setDonyCommissionRate(0.125);
      expect(commissionPercentLabel(fr), '12,5');
      expect(commissionPercentLabel(en), '12.5');
    });

    test('cas limites d\'arrondi (taux → pourcentage)', () {
      setDonyCommissionRate(0.0446); // 4,46 % arrondi au-dessus
      expect(commissionPercentLabel(fr), '4,5');
      expect(commissionPercentLabel(en), '4.5');

      setDonyCommissionRate(0.0444); // 4,44 % arrondi en-dessous
      expect(commissionPercentLabel(fr), '4,4');
      expect(commissionPercentLabel(en), '4.4');

      setDonyCommissionRate(0.0096); // 0,96 % passe à la dizaine
      expect(commissionPercentLabel(fr), '1,0');
      expect(commissionPercentLabel(en), '1.0');
    });

    test(
      'imprécision binaire du taux → arrondi identique à l\'ancien getter '
      '(pas une régression : 0.1205 * 100 vaut 12.049999999999999 en double, '
      'comme avant ce lot ; documenté ici plutôt que "corrigé" pour ne pas '
      'changer un comportement déjà présent dans donyCommissionPercentLabel)',
      () {
        setDonyCommissionRate(0.1205);
        expect(commissionPercentLabel(fr), '12,0');
        expect(commissionPercentLabel(en), '12.0');
      },
    );
  });

  group('reimbursementCapLabel', () {
    tearDown(() => setDonyReimbursementCap(kDonyReimbursementCapDefault));

    test('plafond entier → entier sans décimale, fr et en identiques', () {
      setDonyReimbursementCap(200);
      expect(reimbursementCapLabel(fr), '200');
      expect(reimbursementCapLabel(en), '200');
    });

    test('plafond décimal → décimales à la langue, sans zéro final', () {
      setDonyReimbursementCap(150.5);
      expect(reimbursementCapLabel(fr), '150,5');
      expect(reimbursementCapLabel(en), '150.5');
    });

    test(
      'cas limites : deux décimales exactes, aucun arrondi supplémentaire',
      () {
        // reimbursementCapLabel garde jusqu'à deux décimales (contrairement à
        // commissionPercentLabel qui n'en garde qu'une) : ces valeurs tiennent
        // déjà exactement dans deux décimales, rien à arrondir.
        setDonyReimbursementCap(4.46);
        expect(reimbursementCapLabel(fr), '4,46');
        expect(reimbursementCapLabel(en), '4.46');

        setDonyReimbursementCap(4.44);
        expect(reimbursementCapLabel(fr), '4,44');
        expect(reimbursementCapLabel(en), '4.44');

        setDonyReimbursementCap(12.05);
        expect(reimbursementCapLabel(fr), '12,05');
        expect(reimbursementCapLabel(en), '12.05');

        setDonyReimbursementCap(0.96);
        expect(reimbursementCapLabel(fr), '0,96');
        expect(reimbursementCapLabel(en), '0.96');
      },
    );
  });
}
