import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemSize wire', () {
    test('lecture de chaque valeur du back', () {
      expect(itemSizeFromWire('S'), ItemSize.s);
      expect(itemSizeFromWire('M'), ItemSize.m);
      expect(itemSizeFromWire('L'), ItemSize.l);
      expect(itemSizeFromWire('XL'), ItemSize.xl);
    });

    test('valeur inconnue, minuscule, absente ou non texte : null', () {
      expect(itemSizeFromWire('XXL'), isNull);
      expect(itemSizeFromWire('xl'), isNull);
      expect(itemSizeFromWire('NONE'), isNull);
      expect(itemSizeFromWire(null), isNull);
      expect(itemSizeFromWire(3), isNull);
    });

    test('écriture et aller-retour', () {
      expect(itemSizeToWire(ItemSize.m), 'M');
      for (final size in ItemSize.values) {
        expect(itemSizeFromWire(itemSizeToWire(size)), size);
      }
    });
  });

  group('fitsWithin', () {
    test('une taille tient dans la taille max ou une plus grande', () {
      expect(ItemSize.s.fitsWithin(ItemSize.s), isTrue);
      expect(ItemSize.s.fitsWithin(ItemSize.xl), isTrue);
      expect(ItemSize.l.fitsWithin(ItemSize.l), isTrue);
      expect(ItemSize.l.fitsWithin(ItemSize.m), isFalse);
      expect(ItemSize.xl.fitsWithin(ItemSize.l), isFalse);
    });
  });

  group('ItemSizeL10n', () {
    test('code', () {
      expect([for (final s in ItemSize.values) s.code], ['S', 'M', 'L', 'XL']);
    });

    test('descriptions fr', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(
        [for (final s in ItemSize.values) s.description(l)],
        ['Sac', 'Carton', 'Valise, chaise', 'Meuble'],
      );
    });

    test('descriptions en', () {
      final l = lookupAppLocalizations(AppL10n.en);
      expect(
        [for (final s in ItemSize.values) s.description(l)],
        ['Bag', 'Box', 'Suitcase, chair', 'Furniture'],
      );
    });
  });
}
