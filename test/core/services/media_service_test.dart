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
      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => null);

      final result = await makeService().pick(source: ImageSource.gallery);

      expect(result, isNull);
    });
  });

  group('pick — file too large', () {
    test('throws MediaFileTooLargeException when raw file > 50 MB', () async {
      final bigFile = fakeXFile('big.jpg', DonyMediaService.maxInputBytes + 1);
      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => bigFile);

      await expectLater(
        makeService().pick(source: ImageSource.gallery),
        throwsA(isA<MediaFileTooLargeException>()),
      );
    });

    test('exception exposes maxMb from the configured cap', () {
      const ex = MediaFileTooLargeException(
        60 * 1024 * 1024,
        DonyMediaService.maxInputBytes,
      );
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
      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => video);

      await expectLater(
        makeService().pick(source: ImageSource.gallery),
        throwsA(isA<UnsupportedMediaTypeException>()),
      );
    });
  });

  group('pick — success', () {
    test('returns the compressed file', () async {
      final small = fakeXFile('photo.jpg', 512);
      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => small);

      final result = await makeService().pick(source: ImageSource.gallery);

      expect(result, isNotNull);
      expect(result!.path, equals(small.path));
    });
  });

  group('targetSize', () {
    test('paysage 4000x3000 -> 1600x1200', () {
      expect(DonyMediaService.targetSize(4000, 3000), (
        width: 1600,
        height: 1200,
      ));
    });

    test('portrait 3000x4000 -> 1200x1600', () {
      expect(DonyMediaService.targetSize(3000, 4000), (
        width: 1200,
        height: 1600,
      ));
    });

    test('petite image inchangée (jamais d\'agrandissement)', () {
      expect(DonyMediaService.targetSize(800, 600), (width: 800, height: 600));
    });

    test('exactement 1600x1600 inchangée', () {
      expect(DonyMediaService.targetSize(1600, 1600), (
        width: 1600,
        height: 1600,
      ));
    });

    test('constantes du contrat', () {
      expect(DonyMediaService.maxLongEdgePx, 1600);
      expect(DonyMediaService.jpegQuality, 80);
    });
  });

  group('pick - sortie image/jpeg', () {
    test('le compresseur injecté rend un XFile image/jpeg', () async {
      final photo = fakeXFile('big.png', 512);
      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => photo);
      final service = DonyMediaService(
        imagePicker: mockPicker,
        compressor: (f) async => XFile('${f.path}.jpg', mimeType: 'image/jpeg'),
      );

      final result = await service.pick(source: ImageSource.gallery);

      expect(result!.mimeType, 'image/jpeg');
      expect(result.path, endsWith('.jpg'));
    });
  });
}
