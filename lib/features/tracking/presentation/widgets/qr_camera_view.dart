import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Identifiant du colis (bid) porté par un QR Yadony, ou `null` si le contenu
/// lu n'en est pas un.
///
/// Le QR encode l'URL publique de suivi `…/tracking/<bidId>` : on prend le
/// segment qui suit `tracking` et on exige un UUID, pour qu'un QR quelconque
/// (menu de restaurant, lien marketing) ne déclenche jamais rien.
String? extractBidIdFromQr(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  final segments = uri.pathSegments;
  final idx = segments.indexOf('tracking');
  if (idx == -1 || idx + 1 >= segments.length) return null;
  final candidate = segments[idx + 1];
  return _uuidPattern.hasMatch(candidate) ? candidate : null;
}

/// Premier identifiant de colis Yadony trouvé parmi les codes d'une capture.
String? bidIdFromCapture(BarcodeCapture capture) {
  for (final barcode in capture.barcodes) {
    final raw = barcode.rawValue;
    if (raw == null) continue;
    final bidId = extractBidIdFromQr(raw);
    if (bidId != null) return bidId;
  }
  return null;
}

/// Flux caméra qui lit les QR Yadony et ne rend que l'identifiant du colis.
///
/// Le contrôleur vit ici, démarré et arrêté à la main :
/// - [paused] à `true` coupe la caméra (feuille dépliée, écran recouvert,
///   traitement d'un scan en cours) ; repassé à `false`, elle redémarre ;
/// - l'app mise en arrière-plan coupe aussi la caméra ;
/// - [torchOn] pilote la lampe.
///
/// La permission caméra est demandée au premier démarrage, jamais avant :
/// un écran qui ne monte pas ce widget n'ouvre pas la caméra.
class QrCameraView extends StatefulWidget {
  const QrCameraView({
    super.key,
    required this.onBidId,
    this.paused,
    this.torchOn,
  });

  /// Appelé à chaque QR Yadony détecté tant que la caméra n'est pas en pause.
  /// L'anti-rafale reste à la charge de l'appelant.
  final ValueChanged<String> onBidId;

  final ValueListenable<bool>? paused;
  final ValueListenable<bool>? torchOn;

  @override
  State<QrCameraView> createState() => _QrCameraViewState();
}

class _QrCameraViewState extends State<QrCameraView>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
  );
  bool _appResumed = true;
  bool _disposed = false;

  bool get _shouldRun => _appResumed && !(widget.paused?.value ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.paused?.addListener(_sync);
    widget.torchOn?.addListener(_syncTorch);
    // Le contrôleur ne démarre qu'une fois le widget MobileScanner attaché.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant QrCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) {
      oldWidget.paused?.removeListener(_sync);
      widget.paused?.addListener(_sync);
      _sync();
    }
    if (oldWidget.torchOn != widget.torchOn) {
      oldWidget.torchOn?.removeListener(_syncTorch);
      widget.torchOn?.addListener(_syncTorch);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _sync();
  }

  Future<void> _sync() async {
    if (_disposed) return;
    final value = _controller.value;
    if (_shouldRun) {
      if (value.isRunning || value.isStarting) return;
      try {
        await _controller.start();
      } on Exception {
        // Permission refusée, caméra occupée ou absente : MobileScanner
        // affiche l'erreur via son errorBuilder, rien à faire de plus ici.
        return;
      }
      // Une pause a pu être demandée pendant le démarrage.
      if (!_disposed && !_shouldRun) await _sync();
    } else if (value.isRunning) {
      await _controller.stop();
    }
  }

  void _syncTorch() {
    final wanted = widget.torchOn?.value ?? false;
    final value = _controller.value;
    if (!value.isRunning || value.torchState == TorchState.unavailable) return;
    final isOn = value.torchState == TorchState.on;
    if (wanted != isOn) unawaited(_controller.toggleTorch());
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_shouldRun) return;
    final bidId = bidIdFromCapture(capture);
    if (bidId != null) {
      widget.onBidId(bidId);
    } else if (capture.barcodes.any((b) => b.rawValue != null)) {
      _onForeignCode();
    }
  }

  /// Un QR a bien été lu, mais ce n'est pas celui d'un colis Yadony : le
  /// dire, au lieu de laisser croire que la caméra ne lit rien (FLUTTER-20).
  /// La caméra relit le même code à chaque image : un seul avis toutes les
  /// [_foreignNoticeGap].
  static const _foreignNoticeGap = Duration(milliseconds: 2500);
  DateTime? _lastForeignNotice;
  final _foreignNotice = ValueNotifier<bool>(false);
  Timer? _foreignTimer;

  void _onForeignCode() {
    final now = DateTime.now();
    final last = _lastForeignNotice;
    if (last != null && now.difference(last) < _foreignNoticeGap) return;
    _lastForeignNotice = now;
    unawaited(HapticFeedback.heavyImpact());
    _foreignNotice.value = true;
    _foreignTimer?.cancel();
    _foreignTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!_disposed) _foreignNotice.value = false;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _foreignTimer?.cancel();
    _foreignNotice.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.paused?.removeListener(_sync);
    widget.torchOn?.removeListener(_syncTorch);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, _) => const _CameraUnavailable(),
        ),
        Positioned(
          left: DonySpacing.lg,
          right: DonySpacing.lg,
          bottom: DonySpacing.xl,
          child: ValueListenableBuilder<bool>(
            valueListenable: _foreignNotice,
            builder: (context, show, _) => AnimatedOpacity(
              opacity: show ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Semantics(
                liveRegion: show,
                child: Center(
                  child: Container(
                    key: const Key('qr-foreign-notice'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      context.l10n.qrForeignCodeNotice,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DonyColors.neutral0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ColoredBox(
      color: DonyColors.neutral900,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.xl),
          child: Text(
            context.l10n.qrCameraUnavailable,
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: DonyColors.neutral0.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton lampe des écrans caméra : bascule [torchOn], lu par [QrCameraView].
class QrTorchButton extends StatelessWidget {
  const QrTorchButton({super.key, required this.torchOn});

  final ValueNotifier<bool> torchOn;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: torchOn,
      builder: (context, on, _) => IconButton(
        tooltip: context.l10n.scanTorchToggleTooltip,
        isSelected: on,
        style: IconButton.styleFrom(
          backgroundColor: DonyColors.neutral0.withValues(
            alpha: on ? 0.28 : 0.12,
          ),
          minimumSize: const Size(44, 44),
        ),
        icon: const DonyIcon('zap', color: DonyColors.neutral0, size: 20),
        onPressed: () => torchOn.value = !torchOn.value,
      ),
    );
  }
}

/// Cadre de visée à quatre coins arrondis, posé au-dessus du flux caméra.
/// [detected] affiche la pastille de réussite au centre.
class QrScanFrame extends StatelessWidget {
  const QrScanFrame({
    super.key,
    this.size = 240,
    this.detected = false,
    this.color = DonyColors.neutral0,
  });

  final double size;
  final bool detected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _CornersPainter(color: color)),
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

class _CornersPainter extends CustomPainter {
  const _CornersPainter({required this.color});

  final Color color;

  static const _arm = 34.0;
  static const _radius = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    // Un coin = un bras horizontal, un quart de cercle, un bras vertical.
    void corner(double x, double y, double dx, double dy) {
      final path = Path()
        ..moveTo(x + dx * _arm, y)
        ..lineTo(x + dx * _radius, y)
        ..quadraticBezierTo(x, y, x, y + dy * _radius)
        ..lineTo(x, y + dy * _arm);
      canvas.drawPath(path, paint);
    }

    corner(0, 0, 1, 1);
    corner(w, 0, -1, 1);
    corner(0, h, 1, -1);
    corner(w, h, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _CornersPainter old) => old.color != color;
}
