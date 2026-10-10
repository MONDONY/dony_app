import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter_image_compress/flutter_image_compress.dart';
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

/// Thrown when the picked file is not a supported image (e.g. a video).
class UnsupportedMediaTypeException implements Exception {
  const UnsupportedMediaTypeException(this.name);

  /// Original filename, for context/logging.
  final String name;

  @override
  String toString() =>
      'UnsupportedMediaTypeException: "$name" is not a supported image';
}

/// Central media-picking service — **single source of truth** for all image
/// imports in the app.
///
/// Flow: pick → reject non-images → validate size → compress/resize → return XFile.
///
/// ## Rules
/// - Only images are accepted. `pickImage` already filters to images, but a
///   video that slips through (third-party file manager, renamed file) is
///   rejected → throws [UnsupportedMediaTypeException].
/// - Any picked image is always resized/compressed (see [_compress]); a 20 MB
///   photo is downscaled, not rejected.
/// - [maxInputBytes] (50 MB) is only an out-of-memory safety net for absurd
///   files → throws [MediaFileTooLargeException].
/// - Output is always JPEG, grand côté max [maxLongEdgePx], quality [jpegQuality], jamais d'agrandissement.
///
/// Inject [imagePicker] / [compressor] in tests to avoid platform channels.
class DonyMediaService {
  static const int maxInputBytes = 50 * 1024 * 1024; // 50 MB
  static const int maxLongEdgePx = 1600;
  static const int jpegQuality = 80;

  /// Dimensions cibles : grand côté plafonné à [maxLongEdgePx], ratio conservé,
  /// jamais d'agrandissement. Pure, testée seule.
  @visibleForTesting
  static ({int width, int height}) targetSize(int width, int height) {
    final longEdge = width > height ? width : height;
    if (longEdge <= maxLongEdgePx) return (width: width, height: height);
    final scale = maxLongEdgePx / longEdge;
    return (width: (width * scale).round(), height: (height * scale).round());
  }

  /// File extensions that are explicitly rejected (videos / non-images).
  static const Set<String> _videoExtensions = {
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
    '3gp',
    '3gpp',
    'm4v',
    'flv',
    'wmv',
    'mpeg',
    'mpg',
    'm2ts',
    'ts',
    'mts',
  };

  DonyMediaService({
    ImagePicker? imagePicker,
    Future<XFile> Function(XFile)? compressor,
    Future<({int width, int height})> Function(Uint8List)? dimensionReader,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _compressorOverride = compressor,
       _dimensionReader = dimensionReader ?? _readDimensions;

  final ImagePicker _imagePicker;
  final Future<XFile> Function(XFile)? _compressorOverride;
  final Future<({int width, int height})> Function(Uint8List) _dimensionReader;

  static Future<({int width, int height})> _readDimensions(
    Uint8List bytes,
  ) async {
    final ui.Image image = await decodeImageFromList(bytes);
    final size = (width: image.width, height: image.height);
    image.dispose();
    return size;
  }

  /// Picks an image from [source], rejects videos, then compresses/resizes it.
  ///
  /// Returns `null` if the user cancelled.
  /// Throws [UnsupportedMediaTypeException] if the file is not an image.
  /// Throws [MediaFileTooLargeException] only if the raw file is > 50 MB
  /// (out-of-memory safety net); any smaller image is resized, never rejected.
  Future<XFile?> pick({required ImageSource source}) async {
    final raw = await _imagePicker.pickImage(source: source, imageQuality: 100);
    if (raw == null) {
      return null;
    }

    // Reject videos / non-images up front.
    if (_isVideo(raw.name, raw.mimeType)) {
      throw UnsupportedMediaTypeException(raw.name);
    }

    final size = await raw.length();
    if (size > maxInputBytes) {
      throw MediaFileTooLargeException(size, maxInputBytes);
    }

    final override = _compressorOverride;
    return override != null ? await override(raw) : await _compress(raw);
  }

  /// `true` when the file is a known video, by MIME type or extension.
  bool _isVideo(String name, String? mimeType) {
    if (mimeType != null && mimeType.startsWith('video/')) {
      return true;
    }
    final dot = name.lastIndexOf('.');
    if (dot == -1) {
      return false;
    }
    return _videoExtensions.contains(name.substring(dot + 1).toLowerCase());
  }

  Future<XFile> _compress(XFile source) async {
    final bytes = await source.readAsBytes();
    // minWidth/minHeight sont des bornes minimales du petit côté pour le
    // plugin : on lui passe les dimensions cibles exactes (grand côté plafonné).
    final ({int width, int height}) dims;
    try {
      dims = await _dimensionReader(bytes);
    } catch (_) {
      throw UnsupportedMediaTypeException(source.name);
    }
    final t = targetSize(dims.width, dims.height);
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: t.width,
      minHeight: t.height,
      quality: jpegQuality,
      // ignore: avoid_redundant_argument_values
      format: CompressFormat.jpeg,
    );
    // An empty result means the file could not be decoded as an image
    // (e.g. a video renamed with an image extension).
    if (compressed.isEmpty) {
      throw UnsupportedMediaTypeException(source.name);
    }
    final dir = await getTemporaryDirectory();
    final stamp = source.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final outPath = '${dir.path}/dony_media_$stamp.jpg';
    await File(outPath).writeAsBytes(compressed);
    return XFile(outPath, mimeType: 'image/jpeg');
  }
}
