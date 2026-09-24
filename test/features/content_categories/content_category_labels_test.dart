import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  // Correspondance code → libellé attendu (fr = le label du catalogue lui-
  // même, en = la traduction anglaise) pour chacune des 11 entrées.
  const expectedEn = {
    'DOCUMENTS': 'Documents & paperwork',
    'ALIMENTATION_SECHE': 'Dry food',
    'PRODUITS_FRAIS': 'Fresh / perishable food',
    'COSMETIQUES': 'Cosmetics & perfume',
    'VETEMENTS': 'Clothing & fabrics',
    'CHAUSSURES': 'Shoes',
    'MEDICAMENTS_TRADITIONNELS': 'Traditional medicine',
    'ELECTRONIQUE': 'Phones & electronics',
    'LIVRES': 'Books',
    'CADEAUX': 'Gifts & toys',
    'AUTRE': 'Other',
  };

  group('contentCategoryDisplayName — catalogue canonique', () {
    for (final category in fallbackCatalog) {
      test('${category.code} : fr rend le label du catalogue tel quel', () {
        expect(contentCategoryDisplayName(fr, category.label), category.label);
      });

      test('${category.code} : en rend sa traduction', () {
        expect(
          contentCategoryDisplayName(en, category.label),
          expectedEn[category.code],
        );
      });
    }
  });

  group('contentCategoryDisplayName — libellé libre', () {
    test('un libellé hors catalogue est rendu tel quel en français', () {
      expect(contentCategoryDisplayName(fr, 'Pagne wax'), 'Pagne wax');
    });

    test('un libellé hors catalogue est rendu tel quel en anglais aussi', () {
      expect(contentCategoryDisplayName(en, 'Pagne wax'), 'Pagne wax');
    });
  });
}
