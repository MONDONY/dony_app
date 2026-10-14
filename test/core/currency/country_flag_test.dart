import 'package:dony/core/currency/country_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('code du catalogue : drapeau du pays', () {
    expect(countryFlagEmoji('SN'), '🇸🇳');
    expect(countryFlagEmoji('FR'), '🇫🇷');
  });

  test('code hors catalogue : drapeau quand même (GN)', () {
    expect(countryFlagEmoji('GN'), '🇬🇳');
  });

  test('casse et espaces normalisés', () {
    expect(countryFlagEmoji(' ci '), '🇨🇮');
  });

  test('code vide, nul ou mal formé : null', () {
    expect(countryFlagEmoji(null), isNull);
    expect(countryFlagEmoji(''), isNull);
    expect(countryFlagEmoji('FRA'), isNull);
    expect(countryFlagEmoji('1A'), isNull);
    expect(countryFlagEmoji('É1'), isNull);
  });
}
