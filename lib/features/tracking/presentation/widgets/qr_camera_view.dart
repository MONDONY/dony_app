import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
/// Le QR encode l'URL de la page publique du colis,
/// `https://api.yadony.com/api/v1/tracking/<bidId>/scan` (scannée hors app,
/// elle affiche la page publique). On prend le segment qui suit `tracking`
/// et on exige un UUID, pour qu'un QR quelconque (menu de restaurant, lien
/// marketing) ne déclenche jamais rien.
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

/// État de la lampe tel que la caméra le rapporte.
enum QrTorchStatus {
  /// Caméra arrêtée ou en cours de démarrage : rien à piloter.
  stopped,

  /// La caméra tourne mais l'appareil n'a pas de lampe.
  unavailable,

  /// Lampe éteinte, prête à être allumée.
  off,

  /// Lampe allumée.
  on,
}

/// Traduit l'état du lecteur en état de lampe affichable.
@visibleForTesting
QrTorchStatus qrTorchStatusOf(MobileScannerState state) {
  if (!state.isInitialized) return QrTorchStatus.stopped;
  // À l'arrêt, mobile_scanner garde `unavailable` pour un appareil sans
  // lampe et repasse à `off` sinon : seul le premier cas est définitif.
  if (state.torchState == TorchState.unavailable) {
    return state.isRunning ? QrTorchStatus.unavailable : QrTorchStatus.stopped;
  }
  if (!state.isRunning) return QrTorchStatus.stopped;
  return state.torchState == TorchState.on
      ? QrTorchStatus.on
      : QrTorchStatus.off;
}

/// Lampe des écrans caméra, partagée entre [QrCameraView], qui la pilote,
/// et [QrTorchButton], qui l'affiche.
///
/// Sa valeur est l'état RÉEL rapporté par la caméra, jamais la demande de
/// l'utilisateur : une demande ignorée (caméra à l'arrêt, appareil sans
/// lampe) laissait le bouton croire la lampe allumée (FLUTTER-Q9).
class QrTorch extends ValueNotifier<QrTorchStatus> {
  QrTorch() : super(QrTorchStatus.stopped);

  Future<void> Function()? _toggle;
  bool _disposed = false;

  bool get isOn => value == QrTorchStatus.on;

  /// La lampe peut être allumée ou éteinte maintenant.
  bool get canToggle => value == QrTorchStatus.on || value == QrTorchStatus.off;

  /// Demande à la caméra d'inverser la lampe. Le bouton ne change d'état
  /// qu'une fois la caméra revenue avec le nouvel état réel.
  Future<void> toggle() async {
    if (!canToggle) return;
    await _toggle?.call();
  }

  void _report(QrTorchStatus status) {
    if (!_disposed) value = status;
  }

  @override
  void dispose() {
    _disposed = true;
    _toggle = null;
    super.dispose();
  }
}

/// Flux caméra qui lit les QR Yadony et ne rend que l'identifiant du colis.
///
/// Le contrôleur vit ici, démarré et arrêté à la main :
/// - [paused] à `true` coupe la caméra (feuille dépliée, écran recouvert,
///   traitement d'un scan en cours) ; repassé à `false`, elle redémarre ;
/// - l'app mise en arrière-plan coupe aussi la caméra ;
/// - [torch] pilote la lampe et reçoit son état réel.
///
/// La permission caméra est demandée au premier démarrage, jamais avant :
/// un écran qui ne monte pas ce widget n'ouvre pas la caméra.
class QrCameraView extends StatefulWidget {
  const QrCameraView({
    super.key,
    required this.onBidId,
    this.paused,
    this.torch,
  });

  /// Appelé à chaque QR Yadony détecté tant que la caméra n'est pas en pause.
  /// L'anti-rafale reste à la charge de l'appelant.
  final ValueChanged<String> onBidId;

  final ValueListenable<bool>? paused;
  final QrTorch? torch;

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
    _controller.addListener(_reportTorch);
    _attachTorch(widget.torch);
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
    if (oldWidget.torch != widget.torch) {
      _detachTorch(oldWidget.torch);
      _attachTorch(widget.torch);
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

  void _attachTorch(QrTorch? torch) {
    if (torch == null) return;
    torch._toggle = _toggleTorch;
    _reportTorch();
  }

  /// Rend la lampe à l'arrêt quand la caméra qui la pilotait s'en va.
  /// Après l'image : écrire pendant le démontage rebâtirait le bouton alors
  /// que l'arbre est verrouillé.
  void _detachTorch(QrTorch? torch) {
    if (torch == null || torch._toggle != _toggleTorch) return;
    torch._toggle = null;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => torch._report(QrTorchStatus.stopped),
    );
  }

  Future<void> _toggleTorch() async {
    if (_disposed) return;
    final value = _controller.value;
    if (!value.isRunning || value.torchState == TorchState.unavailable) return;
    await _controller.toggleTorch();
  }

  /// Recopie l'état réel de la lampe, rapporté par la caméra.
  void _reportTorch() {
    final torch = widget.torch;
    if (torch == null || _disposed) return;
    final status = qrTorchStatusOf(_controller.value);
    if (torch.value == status) return;
    // Pendant une construction, un autre widget (le bouton) ne peut pas
    // être rebâti : on attend la fin de l'image.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportTorch());
      return;
    }
    torch._report(status);
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
    _controller.removeListener(_reportTorch);
    _detachTorch(widget.torch);
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

/// Bouton lampe des écrans caméra, piloté par l'état réel de [torch].
///
/// Allumée : fond plein jaune et éclair sombre. Éteinte : fond translucide
/// et éclair barré. Le libellé dit l'action proposée (« Allumer la lampe »,
/// « Éteindre la lampe ») : l'état ne passe jamais par la seule couleur.
/// Caméra à l'arrêt : bouton grisé ; appareil sans lampe : bouton masqué.
class QrTorchButton extends StatelessWidget {
  const QrTorchButton({super.key, required this.torch});

  final QrTorch torch;

  static const _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QrTorchStatus>(
      valueListenable: torch,
      builder: (context, status, _) {
        if (status == QrTorchStatus.unavailable) {
          return const SizedBox.shrink();
        }
        final l = context.l10n;
        final on = status == QrTorchStatus.on;
        final enabled = torch.canToggle;
        final tooltip = switch (status) {
          QrTorchStatus.on => l.scanTorchTurnOffTooltip,
          QrTorchStatus.off => l.scanTorchTurnOnTooltip,
          _ => l.scanTorchUnavailableTooltip,
        };
        final background = on
            ? DonyColors.torchOn
            : DonyColors.neutral0.withValues(alpha: enabled ? 0.12 : 0.06);

        // Fond animé à part : AnimatedContainer reprend d'où il en est si
        // l'état change en pleine transition, sans saut.
        return AnimatedContainer(
          key: const Key('qr-torch-button'),
          duration: _duration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: IconButton(
            tooltip: tooltip,
            isSelected: on,
            style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: enabled
                ? () {
                    unawaited(HapticFeedback.selectionClick());
                    unawaited(torch.toggle());
                  }
                : null,
            icon: AnimatedSwitcher(
              duration: _duration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.25, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: on
                  ? const DonyIcon(
                      'zap',
                      key: ValueKey('torch-on'),
                      color: DonyColors.neutral900,
                      size: 20,
                    )
                  : DonyIcon(
                      'zap-off',
                      key: const ValueKey('torch-off'),
                      color: DonyColors.neutral0.withValues(
                        alpha: enabled ? 1 : 0.4,
                      ),
                      size: 20,
                    ),
            ),
          ),
        );
      },
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
