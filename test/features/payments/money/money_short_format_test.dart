import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:flutter_test/flutter_test.dart';

/// Espaces insécables entre le nombre, l'unité et le symbole (« 22,1 k F CFA ») :
/// seuls les deux premiers espaces de [s] en sont, le symbole garde le sien.
String _n(String s) =>
    s.replaceFirst(' ', '\u00a0').replaceFirst(' ', '\u00a0');

void main() {
  group('formatMoneyShort (FLUTTER-NW)', () {
    test('sous 10 000 : montant exact, comme formatMoney', () {
      expect(formatMoneyShort(9999, 'XOF', 'fr'), formatMoney(9999, 'XOF'));
      expect(formatMoneyShort(155, 'EUR', 'fr'), formatMoney(155, 'EUR'));
      expect(formatMoneyShort(-9999, 'XOF', 'fr'), formatMoney(-9999, 'XOF'));
    });

    test('seuil à 10 000 inclus', () {
      expect(formatMoneyShort(10000, 'XOF', 'fr'), _n('10 k F CFA'));
    });

    test('milliers en F CFA, une décimale, séparateur français', () {
      expect(formatMoneyShort(22071, 'XOF', 'fr'), _n('22,1 k F CFA'));
    });

    test('décimale nulle supprimée', () {
      expect(formatMoneyShort(22000, 'XOF', 'fr'), _n('22 k F CFA'));
      expect(formatMoneyShort(22040, 'XOF', 'fr'), _n('22 k F CFA'));
    });

    test('millions', () {
      expect(formatMoneyShort(1234567, 'XOF', 'fr'), _n('1,2 M F CFA'));
      expect(formatMoneyShort(3000000, 'XOF', 'fr'), _n('3 M F CFA'));
    });

    test('999 950 arrondi passe au million, jamais « 1 000 k »', () {
      expect(formatMoneyShort(999950, 'XOF', 'fr'), _n('1 M F CFA'));
      expect(formatMoneyShort(999940, 'XOF', 'fr'), _n('999,9 k F CFA'));
    });

    test('euros', () {
      expect(formatMoneyShort(12500, 'EUR', 'fr'), _n('12,5 k €'));
    });

    test('anglais : point décimal', () {
      expect(formatMoneyShort(22071, 'XOF', 'en'), _n('22.1 k F CFA'));
      expect(formatMoneyShort(12500, 'EUR', 'en'), _n('12.5 k €'));
      expect(formatMoneyShort(1234567, 'XOF', 'en'), _n('1.2 M F CFA'));
    });

    test('devise à symbole en tête : même place que le format complet', () {
      expect(formatMoneyShort(12500, 'USD', 'en'), '\$12.5k');
      expect(formatMoneyShort(12500, 'GBP', 'en'), '£12.5k');
    });

    test('valeur absolue : un montant négatif s\'abrège aussi', () {
      expect(formatMoneyShort(-22071, 'XOF', 'fr'), _n('-22,1 k F CFA'));
    });
  });
}
