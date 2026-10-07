import 'package:dony/features/messaging/data/chat_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/map_backed_box.dart';

class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  final stored = <String, dynamic>{};
  late ChatDraftStore store;

  setUp(() {
    stored.clear();
    store = ChatDraftStore(mapBackedBox(stored));
  });

  test('sans brouillon : chaîne vide', () {
    expect(store.read('conv-1'), '');
  });

  test('enregistre puis relit le brouillon de la conversation', () async {
    await store.save('conv-1', 'Bonjour, je dépose');
    expect(store.read('conv-1'), 'Bonjour, je dépose');
    expect(stored['${ChatDraftStore.keyPrefix}conv-1'], 'Bonjour, je dépose');
  });

  test(
    'un brouillon par conversation, sans fuite de l\'une à l\'autre',
    () async {
      await store.save('conv-1', 'pour Kadi');
      await store.save('conv-2', 'pour Modibo');
      expect(store.read('conv-1'), 'pour Kadi');
      expect(store.read('conv-2'), 'pour Modibo');
      await store.clear('conv-1');
      expect(store.read('conv-1'), '');
      expect(store.read('conv-2'), 'pour Modibo');
    },
  );

  test('un texte vide ou fait d\'espaces efface le brouillon', () async {
    await store.save('conv-1', 'texte');
    await store.save('conv-1', '   \n');
    expect(store.read('conv-1'), '');
    expect(stored, isEmpty);
  });

  test('le brouillon n\'est pas filtré (seul l\'envoi l\'est)', () async {
    await store.save('conv-1', 'appelle moi au 06 12 34 56 78');
    expect(store.read('conv-1'), 'appelle moi au 06 12 34 56 78');
  });

  test('borné à maxLength caractères, sans couper un emoji', () async {
    final long = '${'a' * (ChatDraftStore.maxLength - 1)}👍🏾xyz';
    await store.save('conv-1', long);
    final saved = store.read('conv-1');
    expect(saved.endsWith('👍🏾'), isTrue);
    expect(saved.startsWith('a' * 10), isTrue);
  });

  test('id de conversation vide : rien n\'est lu ni écrit', () async {
    await store.save('', 'texte');
    await store.clear('');
    expect(store.read(''), '');
    expect(stored, isEmpty);
  });

  test('valeur illisible ou stockage en erreur : repli silencieux', () async {
    stored['${ChatDraftStore.keyPrefix}conv-1'] = 42;
    expect(store.read('conv-1'), '');

    final broken = _MockBox();
    when(() => broken.get(any())).thenThrow(Exception('hive'));
    when(() => broken.put(any(), any())).thenThrow(Exception('hive'));
    when(() => broken.delete(any())).thenThrow(Exception('hive'));
    final failing = ChatDraftStore(broken);
    expect(failing.read('conv-1'), '');
    await failing.save('conv-1', 'texte');
    await failing.clear('conv-1');
  });
}
