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

  group('minBounds', () {
    test('4000x3000 et 3000x4000 -> 1200', () {
      expect(DonyMediaService.minBounds(4000, 3000), 1200);
      expect(DonyMediaService.minBounds(3000, 4000), 1200);
    });

    test('800x600 -> 600 (pas d\'agrandissement)', () {
      expect(DonyMediaService.minBounds(800, 600), 600);
    });

    test(
      'avec l\'échelle du plugin, le grand côté vaut 1600 (brut ou pivoté)',
      () {
        for (final dims in [(4000, 3000), (3000, 4000)]) {
          final s = DonyMediaService.minBounds(dims.$1, dims.$2);
          // Android : scale = max(1, min(w / s, h / s)) sur le bitmap brut.
          for (final raw in [(dims.$1, dims.$2), (dims.$2, dims.$1)]) {
            final scale = [
              1.0,
              [raw.$1 / s, raw.$2 / s].reduce((a, b) => a < b ? a : b),
            ].reduce((a, b) => a > b ? a : b);
            final longEdge = (raw.$1 > raw.$2 ? raw.$1 : raw.$2) / scale;
            expect(longEdge.round(), 1600);
          }
        }
      },
    );
  });

  group('pick - _compress réel avec plugin injecté', () {
    Future<XFile?> run({
      required Future<({int width, int height})> Function(Uint8List) reader,
      required List<Map<String, int>> calls,
    }) async {
      final photo = fakeXFile('p.jpg', 64);
      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => photo);
      final service = DonyMediaService(
        imagePicker: mockPicker,
        dimensionReader: reader,
        tempDirectory: () async => tempDir,
        bytesCompressor:
            (
              bytes, {
              required minWidth,
              required minHeight,
              required quality,
            }) async {
              calls.add({'w': minWidth, 'h': minHeight, 'q': quality});
              return Uint8List.fromList([255, 216, 255]);
            },
      );
      return service.pick(source: ImageSource.gallery);
    }

    test('4000x3000 : bornes 1200/1200, qualité 80, sortie jpeg', () async {
      final calls = <Map<String, int>>[];
      final result = await run(
        reader: (_) async => (width: 4000, height: 3000),
        calls: calls,
      );
      expect(calls.single, {'w': 1200, 'h': 1200, 'q': 80});
      expect(result!.mimeType, 'image/jpeg');
      expect(result.path, endsWith('.jpg'));
    });

    test('échec du lecteur de dimensions -> UnsupportedMediaTypeException', () {
      expect(
        run(reader: (_) async => throw Exception('decode'), calls: []),
        throwsA(isA<UnsupportedMediaTypeException>()),
      );
    });

    test('sortie vide du plugin -> UnsupportedMediaTypeException', () async {
      final photo = fakeXFile('v.jpg', 64);
      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => photo);
      final service = DonyMediaService(
        imagePicker: mockPicker,
        dimensionReader: (_) async => (width: 10, height: 10),
        tempDirectory: () async => tempDir,
        bytesCompressor:
            (
              b, {
              required minWidth,
              required minHeight,
              required quality,
            }) async => Uint8List(0),
      );
      await expectLater(
        service.pick(source: ImageSource.gallery),
        throwsA(isA<UnsupportedMediaTypeException>()),
      );
    });
  });
}
