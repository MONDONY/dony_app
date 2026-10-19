import 'dart:convert';

import 'package:dony/features/payments/data/payer_phone_memory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/form_draft_test_doubles.dart';

void main() {
  const payer = RememberedPayer(
    country: 'CI',
    operatorCode: 'ORANGE_CIV',
    e164: '+2250748840856',
  );

  late InMemoryFormDraftStorage storage;
  String? uid;

  PayerPhoneMemory build() =>
      PayerPhoneMemory(storage: storage, currentUid: () => uid);

  setUp(() {
    storage = InMemoryFormDraftStorage();
    uid = 'uid-1';
  });

  test('save_thenRead_roundTrip', () async {
    final memory = build();
    await memory.save(payer);

    expect(storage.values.keys, ['mm_last_payer_uid-1']);
    expect(await memory.read(), payer);
  });

  test('read_otherUid_returnsNull', () async {
    await build().save(payer);

    uid = 'uid-2';
    expect(await build().read(), isNull);
  });

  test('read_noUid_returnsNull_andSaveWritesNothing', () async {
    uid = null;
    final memory = build();
    await memory.save(payer);

    expect(storage.values, isEmpty);
    expect(await memory.read(), isNull);
  });

  test('read_storageThrows_returnsNull', () async {
    final memory = build();
    await memory.save(payer);

    storage.failReads = true;
    expect(await memory.read(), isNull);
  });

  test('save_storageThrows_isSwallowed', () async {
    storage.failWrites = true;
    await expectLater(build().save(payer), completes);
  });

  test('read_corruptedJson_returnsNull', () async {
    storage.values['mm_last_payer_uid-1'] = 'pas du json';
    expect(await build().read(), isNull);

    storage.values['mm_last_payer_uid-1'] = jsonEncode({'country': 'CI'});
    expect(await build().read(), isNull);
  });
}
