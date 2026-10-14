import 'dart:io';

import 'package:dony/features/tracking/data/tracking_queue_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory base;
  late Directory tmp;
  late TrackingQueuePhotoStore store;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('queue_photo_store_');
    tmp = await base.createTemp('tmp_');
    store = TrackingQueuePhotoStore(
      baseDirectory: () async => base,
      temporaryDirectory: () async => tmp,
      now: () => DateTime.fromMicrosecondsSinceEpoch(42),
    );
  });

  tearDown(() => base.delete(recursive: true));

  test('keep copie la photo et rend son nom relatif', () async {
    final source = File('${base.path}/photo.jpg')..writeAsBytesSync([1, 2]);

    final name = await store.keep(source.path);

    expect(name, '42_photo.jpg');
    final copy = File(await store.resolve(name!));
    expect(copy.path, '${base.path}/${TrackingQueuePhotoStore.folder}/$name');
    expect(copy.readAsBytesSync(), [1, 2]);
  });

  test('keep rend null si la photo est déjà absente', () async {
    expect(await store.keep('${base.path}/absente.jpg'), isNull);
  });

  test('resolve ne sort jamais du répertoire des copies', () async {
    expect(
      await store.resolve('../../etc/passwd'),
      '${base.path}/${TrackingQueuePhotoStore.folder}/passwd',
    );
  });

  test('remove supprime la copie, sans effet si absente ou null', () async {
    final source = File('${base.path}/photo.jpg')..writeAsBytesSync([1]);
    final name = (await store.keep(source.path))!;
    final copy = File(await store.resolve(name));

    await store.remove(name);
    expect(copy.existsSync(), isFalse);
    await expectLater(store.remove(name), completes);
    await expectLater(store.remove(null), completes);
  });

  group('adoptLegacy (FLUTTER-F)', () {
    test('chemin encore présent : copié', () async {
      final source = File('${base.path}/old.jpg')..writeAsBytesSync([3]);
      expect(await store.adoptLegacy(source.path), '42_old.jpg');
    });

    test('retrouvé par son nom dans le répertoire temporaire actuel', () async {
      File('${tmp.path}/cam.jpg').writeAsBytesSync([4]);
      final name = await store.adoptLegacy('/var/OLD-UUID/tmp/cam.jpg');
      expect(name, '42_cam.jpg');
      expect(File(await store.resolve(name!)).readAsBytesSync(), [4]);
    });

    test('retrouvé parmi les copies', () async {
      final copy = File(await store.resolve('7_copie.jpg'))
        ..writeAsBytesSync([5]);
      expect(copy.existsSync(), isTrue);
      expect(await store.adoptLegacy('/var/OLD/7_copie.jpg'), '7_copie.jpg');
    });

    test('introuvable : null', () async {
      expect(await store.adoptLegacy('/var/OLD/absente.jpg'), isNull);
      expect(await store.adoptLegacy('/var/OLD/'), isNull);
    });

    test('répertoire temporaire indisponible : null', () async {
      final broken = TrackingQueuePhotoStore(
        baseDirectory: () async => base,
        temporaryDirectory: () async => throw StateError('no plugin'),
      );
      expect(await broken.adoptLegacy('/var/OLD/x.jpg'), isNull);
    });
  });
}
