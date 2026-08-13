import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';

const _etapeLabels = <String, (String, String?, String?)>{
  'DEPART': ('Départ', null, 'plane-takeoff'),
  'TRANSIT': ('Transit', 'arrow-left-right', null),
  'ARRIVEE': ('Arrivée', null, 'plane-landing'),
};

class ScanPhotoScreen extends StatefulWidget {
  const ScanPhotoScreen({
    super.key,
    required this.bidId,
    required this.etape,
    required this.packageLabel,
  });

  final String bidId;
  final String etape;
  final String packageLabel;

  @override
  State<ScanPhotoScreen> createState() => _ScanPhotoScreenState();
}

class _ScanPhotoScreenState extends State<ScanPhotoScreen> {
  final ValueNotifier<bool> _loading = ValueNotifier(false);
  Position? _position;
  late final Future<void> _gpsFuture;

  bool get _photoRequired =>
      widget.etape == 'DEPART' || widget.etape == 'ARRIVEE';

  @override
  void initState() {
    super.initState();
    _gpsFuture = _captureGps();
  }

  @override
  void dispose() {
    _loading.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        _position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    _loading.value = true;
    await _gpsFuture;
    try {
      final picked = await getIt<DonyMediaService>().pick(
        source: ImageSource.camera,
      );
      if (picked == null || !mounted) {
        _loading.value = false;
        return;
      }
      if (_position != null) await _writeGpsExif(picked.path, _position!);
      if (!mounted) return;
      _navigateToConfirm(photoPath: picked.path);
    } on MediaFileTooLargeException catch (e) {
      if (!mounted) return;
      _loading.value = false;
      DonySnackbar.show(
        context,
        message: 'Photo trop lourde (max ${e.maxMb} Mo). Réessayez.',
        type: DonySnackbarType.error,
      );
    } catch (_) {
      if (mounted) _loading.value = false;
    }
  }

  void _skipPhoto() => _navigateToConfirm(photoPath: null);

  void _navigateToConfirm({required String? photoPath}) {
    context.push<void>(
      '/tracking/scan/confirm',
      extra: <String, dynamic>{
        'bidId': widget.bidId,
        'etape': widget.etape,
        'packageLabel': widget.packageLabel,
        'photoPath': photoPath,
        'gpsLat': _position?.latitude,
        'gpsLon': _position?.longitude,
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final etapeInfo = _etapeLabels[widget.etape];
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: DonyColors.ink900,
      body: SafeArea(
        child: Stack(
          children: [
            // Contexte overlay — haut
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: DonyColors.ink900.withValues(alpha: 0.65),
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.sm,
                  DonySpacing.sm,
                  DonySpacing.sm,
                  DonySpacing.lg,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Fermer',
                          icon: const DonyIcon('x', color: DonyColors.neutral0),
                          onPressed: () => context.pop(),
                        ),
                        Expanded(
                          child: Text(
                            'Photo du colis',
                            textAlign: TextAlign.center,
                            style: tt.bodyMedium?.copyWith(
                              color: DonyColors.neutral0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    // Package pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.md,
                        vertical: DonySpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: DonyColors.neutral0.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(DonyRadius.full),
                        border: Border.all(
                          color: DonyColors.neutral0.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const DonyIcon(
                            'package',
                            color: DonyColors.neutral0,
                            size: 13,
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            widget.packageLabel,
                            style: tt.labelMedium?.copyWith(
                              color: DonyColors.neutral0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    // Étape + badge photo
                    if (etapeInfo != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DonySpacing.md,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(
                                DonyRadius.full,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (etapeInfo.$3 != null)
                                  DonyIcon(
                                    etapeInfo.$3!,
                                    color: DonyColors.neutral0,
                                    size: 12,
                                  )
                                else
                                  DonyIcon(
                                    etapeInfo.$2!,
                                    color: DonyColors.neutral0,
                                    size: 12,
                                  ),
                                const SizedBox(width: DonySpacing.xs),
                                Text(
                                  'Étape : ${etapeInfo.$1}',
                                  style: tt.labelSmall?.copyWith(
                                    color: DonyColors.neutral0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: DonySpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DonySpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (_photoRequired ? cs.error : cs.warning)
                                  .withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(
                                DonyRadius.full,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const DonyIcon(
                                  'camera',
                                  color: DonyColors.neutral0,
                                  size: 11,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _photoRequired
                                      ? 'Photo obligatoire'
                                      : 'Photo optionnelle',
                                  style: tt.labelSmall?.copyWith(
                                    color: DonyColors.neutral0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Guide lignes (centre)
            Center(child: _PhotoFrame()),

            // Actions bas
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
                  bottomPad + DonySpacing.lg,
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _loading,
                  builder: (context, loading, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: loading ? null : _takePhoto,
                          icon: loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: DonyColors.neutral0,
                                  ),
                                )
                              : const DonyIcon('camera'),
                          label: Text(
                            loading ? 'Ouverture...' : 'Prendre la photo',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: DonyColors.neutral0,
                            foregroundColor: DonyColors.ink900,
                            padding: const EdgeInsets.symmetric(
                              vertical: DonySpacing.base,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DonyRadius.lg,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!_photoRequired) ...[
                        const SizedBox(height: DonySpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: loading ? null : _skipPhoto,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DonyColors.neutral0,
                              side: BorderSide(
                                color: DonyColors.neutral0.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: DonySpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  DonyRadius.lg,
                                ),
                              ),
                            ),
                            child: const Text('Passer : continuer sans photo'),
                          ),
                        ),
                      ],
                      const SizedBox(height: DonySpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DonyIcon(
                            'map-pin',
                            color: DonyColors.neutral0.withValues(alpha: 0.5),
                            size: 12,
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            'Géolocalisation automatique',
                            style: tt.labelSmall?.copyWith(
                              color: DonyColors.neutral0.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 160,
      child: CustomPaint(painter: _FramePainter()),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DonyColors.neutral0.withValues(alpha: 0.75)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    final corners = [
      (Offset.zero, const Offset(len, 0), const Offset(0, len)),
      (
        Offset(size.width, 0),
        Offset(size.width - len, 0),
        Offset(size.width, len),
      ),
      (
        Offset(0, size.height),
        Offset(len, size.height),
        Offset(0, size.height - len),
      ),
      (
        Offset(size.width, size.height),
        Offset(size.width - len, size.height),
        Offset(size.width, size.height - len),
      ),
    ];

    for (final (origin, h, v) in corners) {
      canvas.drawLine(origin, h, paint);
      canvas.drawLine(origin, v, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
