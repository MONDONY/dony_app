import 'package:dony/core/money/currency_registry.dart';
import 'package:dony/core/money/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => CurrencyRegistry.instance.resetToFallbackForTest());

  group('formatDual', () {
    test('XOF : dual avec NBSP et zéro décimale', () {
      // 12 × 655.957 = 7871.484 → indicatif HALF_UP unité → 7 871
      expect(formatDual(12.00, localeCurrency: 'XOF'), '12 € (7 871 F CFA)');
    });

    test('XAF : même parité', () {
      expect(formatDual(12.00, localeCurrency: 'XAF'), '12 € (7 871 F CFA)');
    });

    test('EUR : pas de doublon', () {
      expect(formatDual(12.00, localeCurrency: 'EUR'), '12 €');
    });

    test('devise inconnue du registre : EUR seul, rien d’inventé', () {
      expect(formatDual(12.00, localeCurrency: 'MAD'), '12 €');
    });

    test('milliers en EUR aussi', () {
      expect(formatDual(1234.56, localeCurrency: 'EUR'), '1 234,56 €');
    });
  });

  group('formatLocalTransactional', () {
    test('affiche le minor serveur tel quel + code ISO', () {
      expect(formatLocalTransactional(7870, 'XOF'), '7 870 F CFA (XOF)');
    });

    test('EUR : deux décimales virgule', () {
      expect(formatLocalTransactional(1234, 'EUR'), '12,34 € (EUR)');
    });
  });
}
