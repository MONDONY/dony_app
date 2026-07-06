import 'package:dony/core/services/contact_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizePhone strips separators and converts 00 prefix', () {
    expect(normalizePhone('+221 77 123-45-67'), '+221771234567');
    expect(normalizePhone('00221771234567'), '+221771234567');
    expect(normalizePhone('(77) 123.45.67'), '771234567');
  });
}
