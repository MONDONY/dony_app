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
    test(
      'suffixe sous grille en EUR : « + frais de service Yadony (min. 1 €) »',
      () {
        useTestCommissionGrid();
        expect(
          listPriceFeeSuffix(fr, 'EUR'),
          '+ frais de service Yadony (min. 1\u00A0€)',
        );
        expect(listPriceFeeSuffix(en, 'EUR'), contains('Yadony service fee'));
      },
    );

    test('suffixe en XOF contient « 650 » et « F CFA »', () {
      useTestCommissionGrid();
      final suffix = listPriceFeeSuffix(fr, 'XOF')!;
      expect(suffix, contains('650'));
      expect(suffix, contains('F CFA'));
    });

    test('devise absente : repli EUR', () {
      useTestCommissionGrid();
      expect(listPriceFeeSuffix(fr, null), contains('min. 1'));
    });

    test('sans minimum : mention courte, sans montant', () {
      useTestCommissionGrid();
      expect(
        listPriceFeeSuffix(fr, 'EUR', withMinimum: false),
        '+ frais de service',
      );
      expect(
        listPriceFeeSuffix(en, 'EUR', withMinimum: false),
        '+ service fee',
      );
    });

    test('aucun suffixe sans grille', () {
      expect(listPriceFeeSuffix(fr, 'EUR'), isNull);
      expect(listPriceFeeSuffix(fr, 'EUR', withMinimum: false), isNull);
    });
  });

  group('serviceFeeAmountLabel', () {
    test('ajoute « (minimum) » seulement si minimum', () {
      expect(
        serviceFeeAmountLabel(fr, 1, 'EUR', minimum: true),
        '1,00\u00A0€\u00A0(minimum)',
      );
      expect(
        serviceFeeAmountLabel(fr, 1, 'EUR', minimum: false),
        '1,00\u00A0€',
      );
    });
  });
}
