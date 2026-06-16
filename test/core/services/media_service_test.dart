import 'dart:io';
import 'dart:typed_data';

import 'package:dony/core/services/media_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late _MockImagePicker mockPicker;
  late Directory tempDir;

  XFile passthrough(XFile f) => f;

  DonyMediaService makeService({
    Future<XFile?> Function(BuildContext?, XFile, double?)? cropOverride,
  }) =>
      DonyMediaService(
        imagePicker: mockPicker,
        cropOverride: cropOverride,
        compressor: (f) async => passthrough(f),
      );

  XFile fakeXFile(String name, int sizeBytes) {
    final path = '${tempDir.path}/$name';
    File(path).writeAsBytesSync(Uint8List(sizeBytes));
    return XFile(path);
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('media_svc_test_');
    registerFallbackValue(ImageSource.gallery);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    mockPicker = _MockImagePicker();
  });

  group('pick — user cancels at picker', () {
    test('returns null', () async {
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => null);

      final result = await makeService().pick(source: ImageSource.gallery);

      expect(result, isNull);
    });
  });

  group('pick — file too large', () {
    test('throws MediaFileTooLargeException when raw file > 15 MB', () async {
      final bigFile =
          fakeXFile('big.jpg', DonyMediaService.maxInputBytes + 1);
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => bigFile);

      await expectLater(
        makeService().pick(source: ImageSource.gallery),
        throwsA(isA<MediaFileTooLargeException>()),
      );
    });

    test('exception exposes maxMb = 15', () {
      const ex =
          MediaFileTooLargeException(20 * 1024 * 1024, 15 * 1024 * 1024);
      expect(ex.maxMb, equals(15));
    });

    test('exception toString contains byte counts', () {
      const ex = MediaFileTooLargeException(20000000, 15728640);
      expect(ex.toString(), contains('20000000'));
      expect(ex.toString(), contains('15728640'));
    });
  });

  group('pick — withCrop: false', () {
    test('returns XFile without calling cropOverride', () async {
      final small = fakeXFile('photo.jpg', 512);
      bool cropCalled = false;
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => small);

      final result = await makeService(
        cropOverride: (_, f, __) async {
          cropCalled = true;
          return f;
        },
      ).pick(source: ImageSource.camera);

      expect(result, isNotNull);
      expect(cropCalled, isFalse);
    });
  });

  group('pick — withCrop: true', () {
    test('returns null when cropOverride returns null (user cancels)', () async {
      final small = fakeXFile('avatar.jpg', 512);
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => small);

      final result = await makeService(
        cropOverride: (_, __, ___) async => null,
      ).pick(source: ImageSource.gallery, withCrop: true);

      expect(result, isNull);
    });

    test('cropOverride is called with correct file', () async {
      final small = fakeXFile('src.jpg', 512);
      XFile? receivedFile;
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => small);

      await makeService(
        cropOverride: (_, f, __) async {
          receivedFile = f;
          return null;
        },
      ).pick(source: ImageSource.gallery, withCrop: true);

      expect(receivedFile?.path, equals(small.path));
    });

    test('cropOverride receives the aspect ratio', () async {
      final small = fakeXFile('src2.jpg', 512);
      double? receivedRatio;
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => small);

      await makeService(
        cropOverride: (_, f, ratio) async {
          receivedRatio = ratio;
          return null;
        },
      ).pick(
        source: ImageSource.gallery,
        withCrop: true,
        cropAspectRatio: 1.0,
      );

      expect(receivedRatio, equals(1.0));
    });

    test('returns compressed file when cropOverride returns a file', () async {
      final srcFile = fakeXFile('src3.jpg', 512);
      final croppedFile = fakeXFile('cropped.jpg', 256);
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => srcFile);

      final result = await makeService(
        cropOverride: (_, __, ___) async => croppedFile,
      ).pick(
        source: ImageSource.gallery,
        withCrop: true,
      );

      expect(result, isNotNull);
      expect(result!.path, equals(croppedFile.path));
    });
  });
}
