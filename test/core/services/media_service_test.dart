import 'dart:io';
import 'dart:typed_data';

import 'package:dony/core/services/media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

class _MockImageCropper extends Mock implements ImageCropper {}

void main() {
  late _MockImagePicker mockPicker;
  late _MockImageCropper mockCropper;
  late Directory tempDir;

  // Passthrough compressor: returns the XFile unchanged (no native channel).
  XFile passthrough(XFile f) => f;

  DonyMediaService makeService() => DonyMediaService(
        imagePicker: mockPicker,
        imageCropper: mockCropper,
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
    registerFallbackValue(const CropAspectRatio(ratioX: 1, ratioY: 1));
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    mockPicker = _MockImagePicker();
    mockCropper = _MockImageCropper();
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
    test('returns XFile without calling ImageCropper', () async {
      final small = fakeXFile('photo.jpg', 512);
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => small);

      final result =
          await makeService().pick(source: ImageSource.camera);

      expect(result, isNotNull);
      verifyNever(() => mockCropper.cropImage(
            sourcePath: any(named: 'sourcePath'),
            aspectRatio: any(named: 'aspectRatio'),
            uiSettings: any(named: 'uiSettings'),
          ));
    });
  });

  group('pick — withCrop: true', () {
    test('returns null when user cancels crop', () async {
      final small = fakeXFile('avatar.jpg', 512);
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => small);
      when(() => mockCropper.cropImage(
            sourcePath: any(named: 'sourcePath'),
            aspectRatio: any(named: 'aspectRatio'),
            uiSettings: any(named: 'uiSettings'),
          )).thenAnswer((_) async => null);

      final result = await makeService().pick(
        source: ImageSource.gallery,
        withCrop: true,
      );

      expect(result, isNull);
    });

    test('calls ImageCropper with correct sourcePath', () async {
      final small = fakeXFile('src.jpg', 512);
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => small);
      when(() => mockCropper.cropImage(
            sourcePath: any(named: 'sourcePath'),
            aspectRatio: any(named: 'aspectRatio'),
            uiSettings: any(named: 'uiSettings'),
          )).thenAnswer((_) async => null);

      await makeService().pick(source: ImageSource.gallery, withCrop: true);

      verify(() => mockCropper.cropImage(
            sourcePath: small.path,
            aspectRatio: any(named: 'aspectRatio'),
            uiSettings: any(named: 'uiSettings'),
          )).called(1);
    });

    test('returns compressed file when crop succeeds', () async {
      final srcFile = fakeXFile('src2.jpg', 512);
      final croppedFile = fakeXFile('cropped.jpg', 256);
      when(() => mockPicker.pickImage(
            source: any(named: 'source'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => srcFile);
      when(() => mockCropper.cropImage(
            sourcePath: any(named: 'sourcePath'),
            aspectRatio: any(named: 'aspectRatio'),
            uiSettings: any(named: 'uiSettings'),
          )).thenAnswer((_) async => CroppedFile(croppedFile.path));

      final result = await makeService().pick(
        source: ImageSource.gallery,
        withCrop: true,
      );

      expect(result, isNotNull);
      expect(result!.path, equals(croppedFile.path));
    });
  });
}
