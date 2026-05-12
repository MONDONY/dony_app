import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:native_exif/native_exif.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController();

  // ValueNotifier replaces setState for detected flag
  final _detectedNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _scanner.dispose();
    _detectedNotifier.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detectedNotifier.value) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final bidId = _extractBidId(raw);
    if (bidId == null) return;

    _detectedNotifier.value = true;
    _scanner.stop();
    _showScanSheet(bidId);
  }

  String? _extractBidId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final idx = segments.indexOf('tracking');
    if (idx == -1 || idx + 1 >= segments.length) return null;
    final candidate = segments[idx + 1];
    final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    return uuidPattern.hasMatch(candidate) ? candidate : null;
  }

  void _showScanSheet(String bidId) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<TrackingBloc>()),
          BlocProvider.value(value: context.read<RatingBloc>()),
        ],
        child: _ScanConfirmSheet(
          bidId: bidId,
          onClose: () {
            _detectedNotifier.value = false;
            _scanner.start();
          },
          onDeliveryConfirmed: (confirmedBidId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              RatingBottomSheet.show(
                context,
                bidId: confirmedBidId,
                travelerName: "l'expéditeur",
                isTravelerRating: true,
              );
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return BlocListener<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is QrScanSuccess) {
          context.pop(); // close sheet
          _showSuccessDialog(state.event.stepLabel);
        } else if (state is QrScanQueued) {
          context.pop(); // close sheet
          _showQueuedDialog();
        }
      },
      child: Scaffold(
        backgroundColor: DonyColors.ink900,
        body: SafeArea(
          child: Stack(
            children: [
              // Camera feed
              MobileScanner(
                controller: _scanner,
                onDetect: _onDetect,
              ),

              // Top bar (dark overlay)
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
                      // X close
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: DonyColors.white),
                        onPressed: () => context.pop(),
                        tooltip: 'Fermer',
                      ),
                      // Title centered
                      Expanded(
                        child: Text(
                          'Scan départ',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(
                            color: DonyColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Flash
                      IconButton(
                        icon: const Icon(Icons.flash_on_rounded,
                            color: DonyColors.white),
                        onPressed: () => _scanner.toggleTorch(),
                        tooltip: 'Lampe torche',
                      ),
                    ],
                  ),
                ),
              ),

              // Context text below top bar
              Positioned(
                top: 72,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      'colis #A47C',
                      style: tt.labelMedium?.copyWith(
                        color: DonyColors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      'Bonjour Aminata 👋',
                      style: DonyTypography.caveat(
                        fontSize: 28,
                        color: DonyColors.white,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),

              // QR scanner frame (center)
              ValueListenableBuilder<bool>(
                valueListenable: _detectedNotifier,
                builder: (context, detected, _) {
                  return Center(
                    child: _ScanFrame(detected: detected),
                  );
                },
              ),

              // Step indicator + bottom action bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: DonyColors.ink900.withValues(alpha: 0.7),
                  padding: EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.base,
                    DonySpacing.lg,
                    MediaQuery.of(context).padding.bottom + DonySpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step indicator
                      Text(
                        'ÉTAPE 1 SUR 3',
                        style: tt.labelSmall?.copyWith(
                          color: DonyColors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xs),
                      Text(
                        'Colis confirmé en valise',
                        style: tt.bodySmall?.copyWith(
                          color: DonyColors.white,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.base),
                      // Action buttons
                      Row(
                        children: [
                          // Photo button (outlined white)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showManualEntryDialog,
                              icon: const Icon(Icons.camera_alt_outlined,
                                  color: DonyColors.white, size: 18),
                              label: Text(
                                'Photo',
                                style: tt.labelLarge?.copyWith(
                                  color: DonyColors.white,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: DonyColors.white,
                                side: const BorderSide(color: DonyColors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: DonySpacing.md,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: DonySpacing.md),
                          // Confirm button (green filled)
                          Expanded(
                            flex: 2,
                            child: DonyButton(
                              label: 'Confirmer & continuer',
                              icon: Icons.check_rounded,
                              onPressed: _showManualEntryDialog,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    _scanner.stop();
    final ctrl = TextEditingController();
    bool loading = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DonyRadius.sheet)),
          title: Text('Numéro de suivi', style: tt.headlineMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entrez le numéro DON-XXXXXX du colis à scanner.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.md),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'DON-XXXXXX',
                  hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  prefixIcon: Icon(Icons.local_shipping_outlined,
                      color: cs.primary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                ),
                style: tt.titleLarge?.copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading
                  ? null
                  : () {
                      ctx.pop();
                      _scanner.start();
                    },
              child: Text('Annuler',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final number = ctrl.text.trim().toUpperCase();
                      if (number.isEmpty) return;
                      setDialogState(() => loading = true);
                      try {
                        final result = await getIt<TrackingRepository>()
                            .searchByTrackingNumber(number);
                        if (ctx.mounted) {
                          ctx.pop();
                          _detectedNotifier.value = true;
                          _showScanSheet(result.bidId);
                        }
                      } catch (_) {
                        setDialogState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Numéro introuvable. Vérifiez et réessayez.',
                                style: tt.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              backgroundColor: cs.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(DonyRadius.sm)),
                            ),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.md)),
              ),
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.onPrimary),
                    )
                  : Text('Confirmer', style: tt.labelLarge),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (!_detectedNotifier.value) _scanner.start();
    });
  }

  void _showQueuedDialog() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sheet)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.base),
              decoration: BoxDecoration(
                color: cs.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  color: cs.warning, size: 40),
            ),
            const SizedBox(height: DonySpacing.base),
            Text('Scan en attente',
                style: tt.headlineMedium?.copyWith(color: cs.onSurface)),
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Pas de connexion internet. Le scan sera synchronisé automatiquement dès que vous serez en ligne.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ctx.pop();
                context.pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.warning,
                foregroundColor: DonyColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.lg)),
              ),
              child: Text('Compris', style: tt.labelLarge),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String label) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isFinal = isFinalDeliveryStep(label);
    final mascotteType =
        isFinal ? DonyMascotteType.securise : DonyMascotteType.confiant;
    final title = isFinal ? 'Colis livré !' : 'Scan enregistré !';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sheet)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyMascotteAnimated(
              type: mascotteType,
              size: DonyMascotteSize.lg,
              withGlow: isFinal,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(title,
                style: tt.headlineMedium?.copyWith(color: cs.onSurface)),
            const SizedBox(height: DonySpacing.sm),
            Text(label,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ctx.pop();
                context.pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.lg)),
              ),
              child: Text('Terminé', style: tt.labelLarge),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renvoie true si le label correspond à une étape de livraison finale.
///
/// Le `stepLabel` est une chaîne libre côté serveur ; ce matching est
/// pragmatique pour le MVP. Si un enum d'événement est exposé plus tard,
/// migrer vers un match d'enum.
bool isFinalDeliveryStep(String label) {
  final l = label.toLowerCase();
  return l.contains('livr') ||
      l.contains('remis') ||
      l.contains('deliver');
}

// ── Scan frame overlay ────────────────────────────────────────────────────────

class _ScanFrame extends StatelessWidget {
  final bool detected;
  const _ScanFrame({required this.detected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        children: [
          // Corner brackets
          for (final pos in [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(alignment: pos, child: _Corner(alignment: pos)),

          // Success check overlay when detected
          if (detected)
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: DonyColors.white,
                  size: 44,
                ),
              ).animate().scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1.0, 1.0),
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
  final Alignment alignment;
  const _Corner({required this.alignment});

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
  final bool isLeft;
  final bool isTop;
  const _CornerPainter({required this.isLeft, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DonyColors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final dx = isLeft ? 1 : -1;
    final dy = isTop ? 1 : -1;

    canvas.drawLine(Offset(x, y), Offset(x + dx * size.width, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy * size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Confirm bottom sheet ──────────────────────────────────────────────────────

class _ScanConfirmSheet extends StatefulWidget {
  final String bidId;
  final VoidCallback onClose;
  final void Function(String bidId)? onDeliveryConfirmed;

  const _ScanConfirmSheet({
    required this.bidId,
    required this.onClose,
    this.onDeliveryConfirmed,
  });

  @override
  State<_ScanConfirmSheet> createState() => _ScanConfirmSheetState();
}

class _ScanConfirmSheetState extends State<_ScanConfirmSheet> {
  String _eventType = 'DEPART';
  XFile? _photo;
  Position? _position;
  bool _loadingLocation = false;
  bool _photoTooBig = false;
  final _codeController = TextEditingController();

  final _eventTypes = [
    ('DEPART', 'Départ', Icons.flight_takeoff_rounded),
    ('TRANSIT', 'Transit', Icons.sync_alt_rounded),
    ('ARRIVEE', 'Arrivée', Icons.flight_land_rounded),
  ];

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _loadingLocation = true;
      _photoTooBig = false;
    });
    try {
      Position? pos;
      try {
        final permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          pos = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.high));
        }
      } catch (_) {}

      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1080);

      if (picked != null && mounted) {
        final fileSize = await File(picked.path).length();
        if (fileSize > 10 * 1024 * 1024) {
          setState(() {
            _photoTooBig = true;
            _loadingLocation = false;
          });
          return;
        }

        if (pos != null) {
          await _writeGpsExif(picked.path, pos);
        }

        setState(() {
          _photo = picked;
          _position = pos;
          _loadingLocation = false;
        });
      } else {
        if (mounted) setState(() => _loadingLocation = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _writeGpsExif(String path, Position pos) async {
    try {
      final exif = await Exif.fromPath(path);
      await exif.writeAttributes({
        'GPSLatitude': _toExifDms(pos.latitude.abs()),
        'GPSLatitudeRef': pos.latitude >= 0 ? 'N' : 'S',
        'GPSLongitude': _toExifDms(pos.longitude.abs()),
        'GPSLongitudeRef': pos.longitude >= 0 ? 'E' : 'W',
      });
      await exif.close();
    } catch (_) {}
  }

  String _toExifDms(double decimal) {
    final deg = decimal.floor();
    final minFull = (decimal - deg) * 60;
    final min = minFull.floor();
    final sec = ((minFull - min) * 60 * 100).round();
    return '$deg/1,$min/1,$sec/100';
  }

  void _submit(BuildContext context) {
    if (_eventType == 'ARRIVEE') {
      final code = _codeController.text.trim();
      if (code.length != 6) return;
      context.read<TrackingBloc>().add(
            ConfirmDeliveryRequested(bidId: widget.bidId, code: code));
    } else {
      context.read<TrackingBloc>().add(QrScanSubmitRequested(
            bidId: widget.bidId,
            eventType: _eventType,
            photo: _photo,
            gpsLat: _position?.latitude,
            gpsLon: _position?.longitude,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        bottomPad + DonySpacing.lg,
      ),
      child: BlocConsumer<TrackingBloc, TrackingState>(
        listener: (context, state) {
          if (state is DeliveryConfirmSuccess) {
            context.pop();
            widget.onDeliveryConfirmed?.call(state.event.bidId);
          } else if (state is QrScanSuccess || state is QrScanQueued) {
            context.pop();
            widget.onClose();
          }
        },
        builder: (context, state) {
          final isSubmitting =
              state is QrScanSubmitting || state is DeliveryConfirmLoading;
          final isArrivee = _eventType == 'ARRIVEE';

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: Text('QR scanné', style: tt.headlineMedium),
                  ),
                  if (!isSubmitting)
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: cs.onSurfaceVariant),
                      onPressed: () {
                        context.pop();
                        widget.onClose();
                      },
                    ),
                ],
              ),

              const SizedBox(height: DonySpacing.base),

              // Event type selector
              Text(
                'Type d\'étape',
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.sm),
              Row(
                children: _eventTypes.map((type) {
                  final isSelected = _eventType == type.$1;
                  return Expanded(
                    child: GestureDetector(
                      onTap: isSubmitting
                          ? null
                          : () => setState(() => _eventType = type.$1),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        margin: const EdgeInsets.only(right: DonySpacing.sm),
                        padding: const EdgeInsets.symmetric(
                            vertical: DonySpacing.md),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(DonyRadius.md),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : cs.outline,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(type.$3,
                                color: isSelected
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                                size: 20),
                            const SizedBox(height: DonySpacing.xs),
                            Text(
                              type.$2,
                              style: tt.labelSmall?.copyWith(
                                color: isSelected
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: DonySpacing.lg),

              // ARRIVEE: code input — DEPART/TRANSIT: photo
              if (isArrivee) ...[
                Text(
                  'Code de confirmation',
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                    vertical: DonySpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: cs.primary, size: 15),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          'Demandez le code à 6 chiffres au destinataire. Il l\'a reçu de l\'expéditeur.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DonySpacing.md),
                TextField(
                  controller: _codeController,
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: tt.displayMedium?.copyWith(letterSpacing: 10),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '------',
                    hintStyle: tt.displayMedium?.copyWith(
                      color: cs.outlineVariant,
                      letterSpacing: 10,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      borderSide: BorderSide(
                          color: cs.primary, width: 2),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: DonySpacing.base),
                  ),
                ),
              ] else ...[
                Text(
                  'Photo du colis',
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.sm),

                if (_photo == null)
                  GestureDetector(
                    onTap: isSubmitting || _loadingLocation ? null : _pickPhoto,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Center(
                        child: _loadingLocation
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_rounded,
                                      color: cs.primary, size: 20),
                                  const SizedBox(width: DonySpacing.sm),
                                  Text(
                                    'Prendre une photo',
                                    style: tt.titleSmall
                                        ?.copyWith(color: cs.primary),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  )
                else
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        child: Image.file(
                          File(_photo!.path),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: cs.primaryContainer,
                            child: Center(
                                child: Icon(Icons.image_rounded,
                                    color: cs.primary, size: 32)),
                          ),
                        ),
                      ),
                      if (!isSubmitting)
                        Positioned(
                          top: DonySpacing.sm,
                          right: DonySpacing.sm,
                          child: GestureDetector(
                            onTap: () => setState(() => _photo = null),
                            child: Container(
                              padding: const EdgeInsets.all(DonySpacing.xs),
                              decoration: BoxDecoration(
                                  color: DonyColors.ink900.withValues(alpha: 0.54),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  color: DonyColors.white, size: 16),
                            ),
                          ),
                        ),
                    ],
                  ),

                if (_position != null) ...[
                  const SizedBox(height: DonySpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          color: cs.success, size: 14),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        'GPS : ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
                if (_photoTooBig) ...[
                  const SizedBox(height: DonySpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: cs.error, size: 14),
                      const SizedBox(width: DonySpacing.xs),
                      Expanded(
                        child: Text(
                          'Photo trop lourde (max 10 MB). Réessayez.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: DonySpacing.xl),

              // Submit button
              DonyButton(
                label: isSubmitting
                    ? (isArrivee ? 'Confirmation...' : 'Enregistrement...')
                    : (isArrivee ? 'Confirmer la livraison' : 'Confirmer le scan'),
                icon: isArrivee
                    ? Icons.verified_rounded
                    : Icons.check_rounded,
                onPressed: isSubmitting ? null : () => _submit(context),
                isLoading: isSubmitting,
              ),

              if (state is QrScanError || state is DeliveryConfirmError) ...[
                const SizedBox(height: DonySpacing.md),
                Text(
                  state is QrScanError
                      ? ErrorPresenter.resolve(state.error).message
                      : ErrorPresenter.resolve(
                              (state as DeliveryConfirmError).error)
                          .message,
                  style: tt.bodySmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
