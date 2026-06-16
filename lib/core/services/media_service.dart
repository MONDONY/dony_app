import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Thrown when the raw image picked by the user exceeds [maxInputBytes].
class MediaFileTooLargeException implements Exception {
  const MediaFileTooLargeException(this.actualBytes, this.maxBytes);

  final int actualBytes;
  final int maxBytes;

  int get maxMb => maxBytes ~/ (1024 * 1024);

  @override
  String toString() =>
      'MediaFileTooLargeException: file is $actualBytes bytes, max allowed is $maxBytes bytes';
}

/// Central media-picking service — **single source of truth** for all image
/// imports in the app.
///
/// Flow: pick → validate size → [optional crop] → compress → return XFile.
///
/// ## Rules
/// - Raw input > [maxInputBytes] (15 MB) → throws [MediaFileTooLargeException].
/// - Crop is opt-in per call site (avatar: yes, scan photo: no).
/// - Output is always JPEG, max [_maxDimensionPx]×[_maxDimensionPx], quality [_quality].
///
/// Inject [imagePicker] / [imageCropper] / [compressor] in tests to avoid platform channels.
class DonyMediaService {
  static const int maxInputBytes = 15 * 1024 * 1024; // 15 MB
  static const int _maxDimensionPx = 1920;
  static const int _quality = 85;

  DonyMediaService({
    ImagePicker? imagePicker,
    ImageCropper? imageCropper,
    // ignore: invalid_use_of_visible_for_testing_member
    Future<XFile> Function(XFile)? compressor,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _imageCropper = imageCropper ?? ImageCropper(),
        _compressorOverride = compressor;

  final ImagePicker _imagePicker;
  final ImageCropper _imageCropper;
  final Future<XFile> Function(XFile)? _compressorOverride;

  /// Picks an image from [source], optionally crops it, then compresses it.
  ///
  /// Returns `null` if the user cancelled at any step.
  /// Throws [MediaFileTooLargeException] if the raw file is > 15 MB.
  ///
  /// [withCrop] — show a crop UI after picking (useful for avatar, KYC).
  /// [aspectRatio] — lock the crop to a fixed ratio (e.g. 1:1 for avatar).
  /// [cropToolbarColor] — optional colour for the Android crop toolbar.
  Future<XFile?> pick({
    required ImageSource source,
    bool withCrop = false,
    CropAspectRatio? aspectRatio,
    Color? cropToolbarColor,
  }) async {
    final raw = await _imagePicker.pickImage(source: source, imageQuality: 100);
    if (raw == null) {
      return null;
    }

    final size = await raw.length();
    if (size > maxInputBytes) {
      throw MediaFileTooLargeException(size, maxInputBytes);
    }

    XFile current = raw;

    if (withCrop) {
      final cropped = await _imageCropper.cropImage(
        sourcePath: current.path,
        aspectRatio: aspectRatio,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recadrer',
            toolbarColor: cropToolbarColor,
            lockAspectRatio: aspectRatio != null,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
          IOSUiSettings(
            title: 'Recadrer',
            aspectRatioLockEnabled: aspectRatio != null,
            resetAspectRatioEnabled: aspectRatio == null,
          ),
        ],
      );
      if (cropped == null) {
        return null;
      }
      current = XFile(cropped.path);
    }

    final override = _compressorOverride;
    return override != null ? await override(current) : await _compress(current);
  }

  Future<XFile> _compress(XFile source) async {
    final bytes = await source.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      // ignore: avoid_redundant_argument_values
      minWidth: _maxDimensionPx,
      minHeight: _maxDimensionPx,
      quality: _quality,
    );
    final dir = await getTemporaryDirectory();
    final stamp = source.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final outPath = '${dir.path}/dony_media_$stamp.jpg';
    await File(outPath).writeAsBytes(compressed);
    return XFile(outPath, mimeType: 'image/jpeg');
  }
}
