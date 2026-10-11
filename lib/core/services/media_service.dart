import 'dart:io';
import 'dart:ui' as ui;

import 'package:dony/core/services/app_log.dart';
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
/// Flow: pick → reject non-images → validate size → compress/resize → return
/// XFile.
///
/// ## Rules
/// - Only images are accepted. `pickImage` already filters to images, but a
///   video that slips through (third-party file manager, renamed file) is
///   rejected → throws [UnsupportedMediaTypeException].
/// - Any picked image is always resized/compressed (see [_compress]); a 20 MB
///   photo is downscaled, not rejected.
/// - [maxInputBytes] (50 MB) is only an out-of-memory safety net for absurd
///   files → throws [MediaFileTooLargeException].
/// - Output is always JPEG, long edge capped at [maxLongEdgePx], quality
///   [jpegQuality], never upscaled.
///
/// Inject [imagePicker] / [compressor] (or the lower-level [bytesCompressor],
/// [dimensionReader], [tempDirectory]) in tests to avoid platform channels.
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

  /// Bornes à passer au plugin (`minWidth` = `minHeight`) : le petit côté cible.
  ///
  /// Le plugin calcule `scale = max(1, min(w / minWidth, h / minHeight))` (Android)
  /// ou `min(1, s / min(w, h))` (iOS) sur le bitmap brut, avant rotation EXIF.
  /// Des bornes carrées égales au petit côté cible donnent donc le même résultat
  /// que les dimensions soient lues pivotées ou non. Pure, testée seule.
  @visibleForTesting
  static int minBounds(int width, int height) {
    final t = targetSize(width, height);
    return t.width < t.height ? t.width : t.height;
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
    Future<Uint8List> Function(
      Uint8List bytes, {
      required int minWidth,
      required int minHeight,
      required int quality,
    })?
    bytesCompressor,
    Future<Directory> Function()? tempDirectory,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _compressorOverride = compressor,
       _dimensionReader = dimensionReader ?? _readDimensions,
       _bytesCompressor = bytesCompressor ?? _pluginCompress,
       _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final ImagePicker _imagePicker;
  final Future<XFile> Function(XFile)? _compressorOverride;
  final Future<({int width, int height})> Function(Uint8List) _dimensionReader;

  final Future<Uint8List> Function(
    Uint8List bytes, {
    required int minWidth,
    required int minHeight,
    required int quality,
  })
  _bytesCompressor;
  final Future<Directory> Function() _tempDirectory;

  static Future<Uint8List> _pluginCompress(
    Uint8List bytes, {
    required int minWidth,
    required int minHeight,
    required int quality,
  }) => FlutterImageCompress.compressWithList(
    bytes,
    minWidth: minWidth,
    minHeight: minHeight,
    quality: quality,
    // ignore: avoid_redundant_argument_values
    format: CompressFormat.jpeg,
  );

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
    final ({int width, int height}) dims;
    try {
      dims = await _dimensionReader(bytes);
    } catch (e) {
      AppLog.warn('Dimensions de ${source.name} illisibles : $e');
      throw UnsupportedMediaTypeException(source.name);
    }
    // Bornes carrées = petit côté cible (voir [minBounds]).
    final bound = minBounds(dims.width, dims.height);
    final compressed = await _bytesCompressor(
      bytes,
      minWidth: bound,
      minHeight: bound,
      quality: jpegQuality,
    );
    // An empty result means the file could not be decoded as an image
    // (e.g. a video renamed with an image extension).
    if (compressed.isEmpty) {
      throw UnsupportedMediaTypeException(source.name);
    }
    final dir = await _tempDirectory();
    final stamp = source.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final outPath = '${dir.path}/dony_media_$stamp.jpg';
    await File(outPath).writeAsBytes(compressed);
    return XFile(outPath, mimeType: 'image/jpeg');
  }
}
