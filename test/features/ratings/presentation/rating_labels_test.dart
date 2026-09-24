import 'package:dony/features/ratings/presentation/rating_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('ratingStarLabel', () {
    test('1 étoile — fr', () {
      expect(ratingStarLabel(fr, 1), 'Très décevant');
    });
    test('1 étoile — en', () {
      expect(ratingStarLabel(en, 1), 'Very disappointing');
    });

    test('2 étoiles — fr', () {
      expect(ratingStarLabel(fr, 2), 'Décevant');
    });
    test('2 étoiles — en', () {
      expect(ratingStarLabel(en, 2), 'Disappointing');
    });

    test('3 étoiles — fr', () {
      expect(ratingStarLabel(fr, 3), 'Correct');
    });
    test('3 étoiles — en', () {
      expect(ratingStarLabel(en, 3), 'Fair');
    });

    test('4 étoiles — fr', () {
      expect(ratingStarLabel(fr, 4), 'Bien');
    });
    test('4 étoiles — en', () {
      expect(ratingStarLabel(en, 4), 'Good');
    });

    test('5 étoiles — fr', () {
      expect(ratingStarLabel(fr, 5), 'Excellent !');
    });
    test('5 étoiles — en', () {
      expect(ratingStarLabel(en, 5), 'Excellent!');
    });

    test('valeur hors de 1..5 — chaîne vide (comme l\'ancien code)', () {
      expect(ratingStarLabel(fr, 0), '');
    });
  });
}
