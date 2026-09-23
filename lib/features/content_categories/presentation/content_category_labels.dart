import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/l10n/l10n.dart';

/// Résout le libellé AFFICHÉ d'une catégorie de contenu.
///
/// [ContentCategory.label] reste la valeur envoyée, stockée et comparée par
/// le moteur de matching backend (`BidContentRules`) : elle ne change jamais
/// et continue de circuler telle quelle dans les sélections, les `Key(...)`
/// et les comparaisons. Cette fonction ne sert QUE l'affichage.
///
/// - [label] canonique (présent dans [fallbackCatalog]) → traduction de son
///   [ContentCategory.code].
/// - [label] libre (saisi par l'utilisateur, ou catégorie ajoutée côté
///   serveur et inconnue de l'app) → [label] tel quel, dans les deux langues.
String contentCategoryDisplayName(AppLocalizations l, String label) {
  for (final category in fallbackCatalog) {
    if (category.label == label) {
      return _translate(l, category.code);
    }
  }
  return label;
}

String _translate(AppLocalizations l, String code) {
  switch (code) {
    case 'DOCUMENTS':
      return l.contentCategoryDocuments;
    case 'ALIMENTATION_SECHE':
      return l.contentCategoryDryFood;
    case 'PRODUITS_FRAIS':
      return l.contentCategoryFreshFood;
    case 'COSMETIQUES':
      return l.contentCategoryCosmetics;
    case 'VETEMENTS':
      return l.contentCategoryClothing;
    case 'CHAUSSURES':
      return l.contentCategoryShoes;
    case 'MEDICAMENTS_TRADITIONNELS':
      return l.contentCategoryTraditionalMedicine;
    case 'ELECTRONIQUE':
      return l.contentCategoryElectronics;
    case 'LIVRES':
      return l.contentCategoryBooks;
    case 'CADEAUX':
      return l.contentCategoryGifts;
    case 'AUTRE':
      return l.contentCategoryOther;
    default:
      // Inatteignable : [code] provient toujours d'une entrée de
      // [fallbackCatalog] ici, dont les 11 codes sont tous listés ci-dessus.
      return code; // i18n-ignore
  }
}
