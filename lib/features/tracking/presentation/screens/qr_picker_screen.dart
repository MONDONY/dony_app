import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrPickerScreen extends StatefulWidget {
  const QrPickerScreen({super.key});

  @override
  State<QrPickerScreen> createState() => _QrPickerScreenState();
}

class _QrPickerScreenState extends State<QrPickerScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  final ValueNotifier<bool> _detected = ValueNotifier(false);

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void dispose() {
    _scanner.dispose();
    _detected.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected.value) {
      return;
    }
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) {
      return;
    }
    final bidId = _extractBidId(raw);
    if (bidId == null) {
      return;
    }
    _detected.value = true;
    _scanner.stop();
    context.pop<String>(bidId);
  }

  String? _extractBidId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return null;
    }
    final segments = uri.pathSegments;
    final idx = segments.indexOf('tracking');
    if (idx == -1 || idx + 1 >= segments.length) {
      return null;
    }
    final candidate = segments[idx + 1];
    return _uuidPattern.hasMatch(candidate) ? candidate : null;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DonyColors.ink900,
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(controller: _scanner, onDetect: _onDetect),
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: DonyColors.ink900.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: DonySpacing.sm,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const DonyIcon('x', color: DonyColors.neutral0),
                      onPressed: () => context.pop<String?>(),
                    ),
                    Expanded(
                      child: Text(
                        'Lire le QR code',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: DonyColors.neutral0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Activer ou couper la lampe',
                      icon: const DonyIcon('zap', color: DonyColors.neutral0),
                      onPressed: () => _scanner.toggleTorch(),
                    ),
                  ],
                ),
              ),
            ),
            // Scan frame
            ValueListenableBuilder<bool>(
              valueListenable: _detected,
              builder: (context, detected, _) =>
                  Center(child: _QrFrame(detected: detected)),
            ),
            // Hint text
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Text(
                'Pointez vers le QR code du colis',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: DonyColors.neutral0.withValues(alpha: 0.7),
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.detected});
  final bool detected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        children: [
          for (final a in [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: a,
              child: _Corner(alignment: a),
            ),
          if (detected)
            Center(
              child:
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.success,
                      shape: BoxShape.circle,
                    ),
                    child: const DonyIcon(
                      'check',
                      color: DonyColors.neutral0,
                      size: 40,
                    ),
                  ).animate().scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment});
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _CornerPainter(isLeft: isLeft, isTop: isTop),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.isLeft, required this.isTop});
  final bool isLeft;
  final bool isTop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DonyColors.neutral0
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final dx = isLeft ? 1.0 : -1.0;
    final dy = isTop ? 1.0 : -1.0;
    canvas.drawLine(Offset(x, y), Offset(x + dx * size.width, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy * size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
