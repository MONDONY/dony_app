import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Full-screen crop UI — Facebook-style dark overlay, pinch-to-zoom.
///
/// Entry point: [MediaCropScreen.push].
class MediaCropScreen extends StatefulWidget {
  const MediaCropScreen({
    super.key,
    required this.imageBytes,
    this.aspectRatio,
    this.withCircleUi = false,
  });

  final Uint8List imageBytes;
  final double? aspectRatio;
  final bool withCircleUi;

  /// Reads [file], pushes this screen, and returns the cropped [XFile] or
  /// `null` if the user cancelled.
  static Future<XFile?> push(
    BuildContext context, {
    required XFile file,
    double? aspectRatio,
  }) async {
    final bytes = await file.readAsBytes();
    if (!context.mounted) {
      return null;
    }
    return Navigator.of(context, rootNavigator: true).push<XFile?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MediaCropScreen(
          imageBytes: bytes,
          aspectRatio: aspectRatio,
          withCircleUi: aspectRatio != null && aspectRatio == 1.0,
        ),
      ),
    );
  }

  @override
  State<MediaCropScreen> createState() => _MediaCropScreenState();
}

class _MediaCropScreenState extends State<MediaCropScreen> {
  final _controller = CropController();
  CropStatus _cropStatus = CropStatus.nothing;
  bool _isCropping = false;

  bool get _isReady => _cropStatus == CropStatus.ready && !_isCropping;

  void _confirmCrop() {
    if (!_isReady) {
      return;
    }
    setState(() => _isCropping = true);
    if (widget.withCircleUi) {
      _controller.cropCircle();
    } else {
      _controller.crop();
    }
  }

  Future<void> _onCropped(CropResult result) async {
    if (result is CropSuccess) {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/dony_crop_$ts.jpg';
      await File(path).writeAsBytes(result.croppedImage);
      if (mounted) {
        Navigator.of(context).pop(XFile(path, mimeType: 'image/jpeg'));
      }
    } else {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DonyColors.ink900,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              isReady: _isReady,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _confirmCrop,
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Crop(
                    image: widget.imageBytes,
                    controller: _controller,
                    aspectRatio:
                        widget.withCircleUi ? 1.0 : widget.aspectRatio,
                    withCircleUi: widget.withCircleUi,
                    onCropped: _onCropped,
                    onStatusChanged: (s) {
                      if (mounted) {
                        setState(() => _cropStatus = s);
                      }
                    },
                    maskColor: Colors.black.withValues(alpha: 0.65),
                    baseColor: DonyColors.ink900,
                    // ignore: avoid_redundant_argument_values — 0 is default but
                    // kept for symmetry with the non-circular case (4).
                    radius: widget.withCircleUi ? 0 : 4,
                    progressIndicator: const Center(
                      child: CircularProgressIndicator(
                        color: DonyColors.neutral0,
                        strokeWidth: 2,
                      ),
                    ),
                    initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                      size: 0.8,
                      aspectRatio: widget.withCircleUi
                          ? 1.0
                          : widget.aspectRatio,
                    ),
                  ),
                  if (_isCropping)
                    Container(
                      color: DonyColors.ink900.withValues(alpha: 0.55),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: DonyColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isReady,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool isReady;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.close,
              color: DonyColors.neutral0,
              size: 22,
            ),
            onPressed: onCancel,
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: isReady ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: FilledButton(
              onPressed: isReady ? onConfirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: DonyColors.primary,
                disabledBackgroundColor:
                    DonyColors.primary.withValues(alpha: 0.4),
                foregroundColor: DonyColors.neutral0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Valider'),
            ),
          ),
        ],
      ),
    );
  }
}
