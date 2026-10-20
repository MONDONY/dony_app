import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/commission_grid_test_doubles.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

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
        // reimbursementCapLabel garde jusqu'à deux décimales : ces valeurs
        // tiennent déjà exactement dans deux décimales, rien à arrondir.
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

  group('listPriceFeeSuffix', () {
    // YADONY-FLUTTER-PROD-1J : le minimum n'est jamais cité.
    test('sous grille : mention courte, sans minimum', () {
      useTestCommissionGrid();
      expect(listPriceFeeSuffix(fr, 'EUR'), '+ frais de service');
      expect(listPriceFeeSuffix(en, 'EUR'), '+ service fee');
      expect(listPriceFeeSuffix(fr, 'XOF'), isNot(contains('650')));
      expect(listPriceFeeSuffix(fr, null), isNot(contains('min')));
    });

    test('aucun suffixe sans grille', () {
      expect(listPriceFeeSuffix(fr, 'EUR'), isNull);
    });
  });

  group('serviceFeeAmountLabel', () {
    test('montant seul, jamais « (minimum) »', () {
      expect(serviceFeeAmountLabel(1, 'EUR'), '1,00\u00A0€');
      expect(serviceFeeAmountLabel(650, 'XOF'), isNot(contains('minimum')));
    });
  });
}
