import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('villes des corridors dony', () {
    expect(cityFlag('Paris'), '🇫🇷');
    expect(cityFlag('lyon'), '🇫🇷');
    expect(cityFlag('MARSEILLE'), '🇫🇷');
    expect(cityFlag('Dakar'), '🇸🇳');
    expect(cityFlag('Abidjan'), '🇨🇮');
    expect(cityFlag('Bamako'), '🇲🇱');
    expect(cityFlag('Douala'), '🇨🇲');
    expect(cityFlag('Yaoundé'), '🇨🇲');
  });

  test('ville inconnue → null (fallback point bleu)', () {
    expect(cityFlag('Tombouctou-les-Bains'), isNull);
    expect(cityFlag(''), isNull);
  });

  test('tolère accents et espaces', () {
    expect(cityFlag(' yaounde '), '🇨🇲');
  });
}
