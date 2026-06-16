import 'dart:io';
import 'dart:typed_data';

import 'package:dony/core/services/media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late _MockImagePicker mockPicker;
  late Directory tempDir;

  XFile passthrough(XFile f) => f;

  DonyMediaService makeService() => DonyMediaService(
        imagePicker: mockPicker,
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
    test('throws MediaFileTooLargeException when raw file > 50 MB', () async {
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

    test('exception exposes maxMb from the configured cap', () {
      const ex = MediaFileTooLargeException(
          60 * 1024 * 1024, DonyMediaService.maxInputBytes);
      expect(ex.maxMb, equals(50));
    });

    test('exception toString contains byte counts', () {
      const ex = MediaFileTooLargeException(20000000, 15728640);
      expect(ex.toString(), contains('20000000'));
      expect(ex.toString(), contains('15728640'));
    });
  });

  group('pick — rejects videos', () {
    test('throws UnsupportedMediaTypeException for a video file', () async {
      final video = fakeXFile('clip.mp4', 1024);
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => video);

      await expectLater(
        makeService().pick(source: ImageSource.gallery),
        throwsA(isA<UnsupportedMediaTypeException>()),
      );
    });
  });

  group('pick — success', () {
    test('returns the compressed file', () async {
      final small = fakeXFile('photo.jpg', 512);
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => small);

      final result = await makeService().pick(source: ImageSource.gallery);

      expect(result, isNotNull);
      expect(result!.path, equals(small.path));
    });
  });
}
