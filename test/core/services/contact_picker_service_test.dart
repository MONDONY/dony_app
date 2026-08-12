import 'package:dony/core/services/contact_picker_service.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNativePicker extends Mock implements FlutterNativeContactPicker {}

void main() {
  test('normalizePhone strips separators and converts 00 prefix', () {
    expect(normalizePhone('+221 77 123-45-67'), '+221771234567');
    expect(normalizePhone('00221771234567'), '+221771234567');
    expect(normalizePhone('(77) 123.45.67'), '771234567');
  });

  test('default constructor instantiates its own native picker', () {
    expect(ContactPickerService(), isNotNull);
  });

  group('ContactPickerService.pick', () {
    late MockNativePicker native;
    late ContactPickerService service;

    setUp(() {
      native = MockNativePicker();
      service = ContactPickerService(picker: native);
    });

    test('returns normalized first phone number', () async {
      when(() => native.selectContact()).thenAnswer(
        (_) async => Contact(
          fullName: 'Mamadou Diallo',
          phoneNumbers: ['+221 77 123-45-67', '+221 78 000 00 00'],
        ),
      );

      final picked = await service.pick();

      expect(picked, isNotNull);
      expect(picked!.fullName, 'Mamadou Diallo');
      expect(picked.phone, '+221771234567');
    });

    test('returns phone null when contact has no phone numbers', () async {
      when(() => native.selectContact())
          .thenAnswer((_) async => Contact(fullName: 'Sans Numéro'));

      final picked = await service.pick();

      expect(picked, isNotNull);
      expect(picked!.fullName, 'Sans Numéro');
      expect(picked.phone, isNull);
    });

    test('returns null when user cancels (null contact)', () async {
      when(() => native.selectContact()).thenAnswer((_) async => null);

      expect(await service.pick(), isNull);
    });

    test('returns null on platform exception', () async {
      when(() => native.selectContact())
          .thenThrow(Exception('platform error'));

      expect(await service.pick(), isNull);
    });
  });
}
