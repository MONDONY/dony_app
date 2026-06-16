import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Full-screen crop UI — image moves/zooms under a fixed frame.
///
/// Pure Flutter (InteractiveViewer + dart:ui crop). Works on all renderers.
class MediaCropScreen extends StatefulWidget {
  const MediaCropScreen({
    super.key,
    required this.imageBytes,
    this.aspectRatio,
  });

  final Uint8List imageBytes;
  final double? aspectRatio;

  static Future<XFile?> push(
    BuildContext context, {
    required XFile file,
    double? aspectRatio,
  }) async {
    var bytes = await file.readAsBytes();
    bytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1500,
      minHeight: 1500,
      quality: 90,
    );
    if (!context.mounted) {
      return null;
    }
    return Navigator.of(context, rootNavigator: true).push<XFile?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            MediaCropScreen(imageBytes: bytes, aspectRatio: aspectRatio),
      ),
    );
  }

  @override
  State<MediaCropScreen> createState() => _MediaCropScreenState();
}

class _MediaCropScreenState extends State<MediaCropScreen> {
  ui.Image? _image;
  bool _cropping = false;
  final _ctrl = TransformationController();

  // Key on the image layer RepaintBoundary (no overlay).
  final _imageKey = GlobalKey();

  // Frame dimensions — set during layout.
  double _frameW = 0;
  double _frameH = 0;
  double _viewW = 0;
  double _viewH = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _image?.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _image = frame.image);
    }
  }

  /// Fit the image to fill the frame on first load.
  void _initTransform() {
    final img = _image;
    if (img == null || _frameW == 0 || _viewW == 0) {
      return;
    }
    if (_ctrl.value != Matrix4.identity()) {
      return;
    }
    final ratio = widget.aspectRatio ?? (_frameW / _frameH);
    final imgAr = img.width / img.height;
    final double scale;
    if (imgAr > ratio) {
      scale = _frameH / img.height;
    } else {
      scale = _frameW / img.width;
    }
    final dx = (_viewW - img.width * scale) / 2;
    final dy = (_viewH - img.height * scale) / 2;
    _ctrl.value = Matrix4.identity()
      // ignore: deprecated_member_use
      ..scale(scale)
      // ignore: deprecated_member_use
      ..translate(dx / scale, dy / scale);
  }

  Future<void> _confirm() async {
    final img = _image;
    if (img == null || _cropping || _frameW == 0) {
      return;
    }
    setState(() => _cropping = true);

    try {
      final boundary =
          _imageKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _cropping = false);
        return;
      }

      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final full = await boundary.toImage(pixelRatio: pixelRatio);

      // Frame offset inside the image layer (which covers the full viewport).
      final left = ((_viewW - _frameW) / 2 * pixelRatio).round();
      final top = ((_viewH - _frameH) / 2 * pixelRatio).round();
      final w = (_frameW * pixelRatio).round();
      final h = (_frameH * pixelRatio).round();

      // Crop by redrawing only the frame portion.
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        full,
        Rect.fromLTWH(
            left.toDouble(), top.toDouble(), w.toDouble(), h.toDouble()),
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint(),
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(w, h);
      full.dispose();

      final byteData =
          await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();

      if (byteData == null) {
        setState(() => _cropping = false);
        return;
      }

      final jpg = await FlutterImageCompress.compressWithList(
        byteData.buffer.asUint8List(),
        minWidth: 1080,
        minHeight: 1080, // ignore: avoid_redundant_argument_values
        quality: 90,
      );

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/dony_crop_$ts.jpg';
      await File(path).writeAsBytes(jpg);

      if (mounted) {
        Navigator.of(context).pop(XFile(path, mimeType: 'image/jpeg'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cropping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: DonyColors.neutral0, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: (img != null && !_cropping) ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: FilledButton(
                      onPressed: (img != null && !_cropping) ? _confirm : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: DonyColors.primary,
                        disabledBackgroundColor:
                            DonyColors.primary.withValues(alpha: 0.4),
                        foregroundColor: DonyColors.neutral0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      child: _cropping
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: DonyColors.neutral0, strokeWidth: 2),
                            )
                          : const Text('Valider'),
                    ),
                  ),
                ],
              ),
            ),

            // Crop area
            Expanded(
              child: img == null
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: DonyColors.neutral0, strokeWidth: 2))
                  : LayoutBuilder(builder: (ctx, constraints) {
                      _viewW = constraints.maxWidth;
                      _viewH = constraints.maxHeight;
                      final ratio =
                          widget.aspectRatio ?? (_viewW / _viewH * 0.9);
                      _frameW = _viewW * 0.88;
                      _frameH = _frameW / ratio;

                      // Fit image to frame on first build.
                      WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _initTransform());

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Image layer — captured by RepaintBoundary
                          RepaintBoundary(
                            key: _imageKey,
                            child: InteractiveViewer(
                              transformationController: _ctrl,
                              minScale: 0.1,
                              maxScale: 10.0,
                              child: SizedBox(
                                width: _viewW,
                                height: _viewH,
                                child: RawImage(image: img),
                              ),
                            ),
                          ),
                          // Overlay — NOT inside RepaintBoundary
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _OverlayPainter(
                                  frameW: _frameW,
                                  frameH: _frameH,
                                  isCircle: widget.aspectRatio == 1.0,
                                ),
                              ),
                            ),
                          ),
                          // Cropping spinner
                          if (_cropping)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: DonyColors.primary, strokeWidth: 2),
                              ),
                            ),
                        ],
                      );
                    }),
            ),

            // Hint
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Déplace et pince pour cadrer',
                style: TextStyle(
                  color: DonyColors.neutral0.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({
    required this.frameW,
    required this.frameH,
    required this.isCircle,
  });

  final double frameW;
  final double frameH;
  final bool isCircle;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final frameRect = Rect.fromCenter(
        center: Offset(cx, cy), width: frameW, height: frameH);

    // Dark scrim with transparent frame hole
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (isCircle) {
      path.addOval(frameRect);
    } else {
      path.addRRect(
          RRect.fromRectAndRadius(frameRect, const Radius.circular(4)));
    }
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, scrimPaint);

    // Frame border
    final borderPaint = Paint()
      ..color = DonyColors.neutral0.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (isCircle) {
      canvas.drawOval(frameRect, borderPaint);
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(frameRect, const Radius.circular(4)),
          borderPaint);
    }

    // Corner handles
    const len = 22.0;
    final cornerPaint = Paint()
      ..color = DonyColors.neutral0
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (origin, hEnd, vEnd) in [
      (frameRect.topLeft, Offset(frameRect.left + len, frameRect.top),
          Offset(frameRect.left, frameRect.top + len)),
      (frameRect.topRight, Offset(frameRect.right - len, frameRect.top),
          Offset(frameRect.right, frameRect.top + len)),
      (frameRect.bottomLeft, Offset(frameRect.left + len, frameRect.bottom),
          Offset(frameRect.left, frameRect.bottom - len)),
      (frameRect.bottomRight, Offset(frameRect.right - len, frameRect.bottom),
          Offset(frameRect.right, frameRect.bottom - len)),
    ]) {
      canvas.drawLine(origin, hEnd, cornerPaint);
      canvas.drawLine(origin, vEnd, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.frameW != frameW || old.frameH != frameH || old.isCircle != isCircle;
}
