import 'dart:io';

import 'package:dony/features/tracking/data/tracking_queue_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory base;
  late TrackingQueuePhotoStore store;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('queue_photo_store_');
    store = TrackingQueuePhotoStore(
      baseDirectory: () async => base,
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
}
