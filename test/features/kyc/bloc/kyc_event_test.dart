// ignore_for_file: prefer_const_constructors
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KycEvent', () {
    test('KycSessionRequested is a KycEvent', () {
      expect(KycSessionRequested(), isA<KycEvent>());
    });

    test('KycStatusRefreshed is a KycEvent', () {
      expect(KycStatusRefreshed(), isA<KycEvent>());
    });
  });
}
