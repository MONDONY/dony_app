import 'package:dony/core/phone/phone_last_digits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numéro complet ou masqué : deux derniers chiffres', () {
    expect(phoneLastDigits('+2250748840856'), '56');
    expect(phoneLastDigits('+225 07 •• •• 56'), '56');
    expect(phoneLastDigits('+221 ** ** 12 34', count: 4), '1234');
  });

  test('trop court ou sans chiffre : ce qu\'il reste', () {
    expect(phoneLastDigits('7'), '7');
    expect(phoneLastDigits('••'), isEmpty);
  });
}
