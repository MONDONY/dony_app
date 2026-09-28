import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/presentation/widgets/qr_camera_view.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Lecteur QR plein écran qui rend l'identifiant du colis lu à l'appelant
/// (`context.push<String?>('/tracking/scan/qr-picker')`).
class QrPickerScreen extends StatefulWidget {
  const QrPickerScreen({super.key});

  @override
  State<QrPickerScreen> createState() => _QrPickerScreenState();
}

class _QrPickerScreenState extends State<QrPickerScreen> {
  final ValueNotifier<bool> _detected = ValueNotifier(false);
  final ValueNotifier<bool> _torchOn = ValueNotifier(false);

  @override
  void dispose() {
    _detected.dispose();
    _torchOn.dispose();
    super.dispose();
  }

  void _onBidId(String bidId) {
    if (_detected.value) return;
    _detected.value = true;
    context.pop<String>(bidId);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Scaffold(
      backgroundColor: DonyColors.ink900,
      body: SafeArea(
        child: Stack(
          children: [
            QrCameraView(
              onBidId: _onBidId,
              paused: _detected,
              torchOn: _torchOn,
            ),
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
                      tooltip: l.commonClose,
                      icon: const DonyIcon('x', color: DonyColors.neutral0),
                      onPressed: () => context.pop<String?>(),
                    ),
                    Expanded(
                      child: Text(
                        l.scanQrPickerTitle,
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: DonyColors.neutral0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    QrTorchButton(torchOn: _torchOn),
                  ],
                ),
              ),
            ),
            // Scan frame
            ValueListenableBuilder<bool>(
              valueListenable: _detected,
              builder: (context, detected, _) =>
                  Center(child: QrScanFrame(detected: detected)),
            ),
            // Hint text
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Text(
                l.scanQrPickerHint,
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
