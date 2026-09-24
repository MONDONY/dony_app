import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Le cache est un état global ; on le remet au défaut après chaque test
  // pour ne pas polluer les autres suites.
  tearDown(() => setDonyReimbursementCap(kDonyReimbursementCapDefault));

  test('default reimbursement cap is 50', () {
    expect(donyReimbursementCapEur, kDonyReimbursementCapDefault);
    expect(donyReimbursementCapEur, 50.0);
  });

  test('setDonyReimbursementCap accepts positive values', () {
    setDonyReimbursementCap(75);
    expect(donyReimbursementCapEur, 75.0);
  });

  test('setDonyReimbursementCap ignores non-positive values', () {
    setDonyReimbursementCap(75);
    setDonyReimbursementCap(0);
    setDonyReimbursementCap(-5);
    expect(donyReimbursementCapEur, 75.0);
  });
}
