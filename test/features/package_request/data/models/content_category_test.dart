import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentCategory', () {
    test('has 9 values', () {
      expect(ContentCategory.values.length, 9);
    });

    test('wireName round-trip via fromWire', () {
      for (final c in ContentCategory.values) {
        expect(ContentCategory.fromWire(c.wireName), c);
      }
    });

    test('fromWire returns autre for null', () {
      expect(ContentCategory.fromWire(null), ContentCategory.autre);
    });

    test('fromWire returns autre for empty string', () {
      expect(ContentCategory.fromWire(''), ContentCategory.autre);
    });

    test('fromWire returns autre for unknown wireName', () {
      expect(ContentCategory.fromWire('UNKNOWN_VALUE'), ContentCategory.autre);
    });

    test('isUrgent is true only for medicaments', () {
      for (final c in ContentCategory.values) {
        expect(
          c.isUrgent,
          c == ContentCategory.medicaments,
          reason: '${c.wireName} urgent flag mismatch',
        );
      }
    });

    test('wireNames are unique and uppercase', () {
      final seen = <String>{};
      for (final c in ContentCategory.values) {
        expect(
          seen.add(c.wireName),
          isTrue,
          reason: 'duplicate wireName: ${c.wireName}',
        );
        expect(
          c.wireName,
          equals(c.wireName.toUpperCase()),
          reason: '${c.wireName} should be uppercase',
        );
      }
    });

    test('labels are non-empty FR text', () {
      for (final c in ContentCategory.values) {
        expect(c.label.isNotEmpty, isTrue);
        expect(
          c.label.length,
          lessThan(20),
          reason: 'label ${c.label} too long for chip display',
        );
      }
    });

    test('emojis are non-empty', () {
      for (final c in ContentCategory.values) {
        expect(c.emoji.isNotEmpty, isTrue, reason: '${c.wireName} emoji vide');
      }
    });

    test('predefinedLabels exclut Autre (8 valeurs)', () {
      expect(ContentCategory.predefinedLabels.length, 8);
      expect(ContentCategory.predefinedLabels.contains('Autre'), isFalse);
      expect(ContentCategory.predefinedLabels.contains('Vêtements'), isTrue);
    });

    test('splitWire découpe + trim + filtre les vides', () {
      expect(ContentCategory.splitWire('Vêtements,Médicaments , Fragile'), [
        'Vêtements',
        'Médicaments',
        'Fragile',
      ]);
      expect(ContentCategory.splitWire(''), isEmpty);
      expect(ContentCategory.splitWire(null), isEmpty);
    });

    test('emojiForLabel : prédéfini → son emoji, libre → 📦', () {
      expect(
        ContentCategory.emojiForLabel('Vêtements'),
        ContentCategory.vetements.emoji,
      );
      expect(ContentCategory.emojiForLabel('Truc bizarre'), '📦');
      expect(ContentCategory.emojiForLabel(null), '📦');
    });
  });
}
