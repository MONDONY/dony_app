import 'dart:async';
import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

// Icônes uniquement : le libellé se calcule via trackingStepLabel.
const _etapeIcons = <String, (String?, String?)>{
  'DEPART': (null, 'plane-takeoff'),
  'TRANSIT': ('arrow-left-right', null),
  'ARRIVEE': (null, 'plane-landing'),
};

/// Photo prise en mode « retour de résultat » ([ScanPhotoScreen.returnResult]).
class ScanPhotoResult {
  const ScanPhotoResult({required this.photoPath, this.position});

  final String photoPath;

  /// Position relevée avant la photo, `null` sans permission ou sans signal.
  final ScanPosition? position;
}

class ScanPhotoScreen extends StatefulWidget {
  const ScanPhotoScreen({
    super.key,
    required this.bidId,
    required this.etape,
    required this.packageLabel,
    this.returnResult = false,
    this.scanMethod,
    this.deliveryWindow,
    this.locator = const ScanLocator(),
  });

  final String bidId;
  final String etape;
  final String packageLabel;

  /// Onglet Suivi : la photo (obligatoire) est rendue à l'appelant par
  /// `context.pop(ScanPhotoResult)` au lieu d'ouvrir la confirmation.
  final bool returnResult;

  /// Provenance transmise à la confirmation ; `null` : rien n'est envoyé.
  final ScanMethod? scanMethod;

  /// Départ du trajet, transmis à la confirmation de livraison (ARRIVEE)
  /// pour y verrouiller le bouton avant le départ ; `null` : inconnu.
  final DeliveryWindow? deliveryWindow;

  final ScanLocator locator;

  /// Taille maximale acceptée par le back pour une photo d'étape.
  static const maxPhotoBytes = 10 * 1024 * 1024;

  @override
  State<ScanPhotoScreen> createState() => _ScanPhotoScreenState();
}

class _ScanPhotoScreenState extends State<ScanPhotoScreen> {
  final ValueNotifier<_Busy> _busy = ValueNotifier(_Busy.idle);

  /// Position relevée en arrière-plan dès l'ouverture : `null` tant qu'elle
  /// n'est pas connue (ou introuvable). Les coordonnées arrivent d'abord, le
  /// lieu lisible (réseau) ensuite.
  final ValueNotifier<ScanPosition?> _position = ValueNotifier(null);
  late final Future<void> _gpsFuture;

  /// Attente maximale de la position une fois la photo prise. L'appareil
  /// photo, lui, ne l'attend jamais (FLUTTER-D1).
  static const _positionGrace = Duration(seconds: 5);

  bool get _photoRequired =>
      widget.returnResult ||
      widget.etape == 'DEPART' ||
      widget.etape == 'ARRIVEE';

  @override
  void initState() {
    super.initState();
    _gpsFuture = _captureGps();
  }

  @override
  void dispose() {
    _busy.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    final coordinates = await widget.locator.captureCoordinates();
    if (coordinates == null || !mounted) return;
    _position.value = coordinates;
    final located = await widget.locator.resolveLabel(coordinates);
    if (mounted) _position.value = located;
  }

  Future<void> _takePhoto() async {
    _busy.value = _Busy.opening;
    try {
      // La recherche GPS, lancée à l'ouverture de l'écran, continue pendant
      // la prise de vue : l'appareil photo s'ouvre sans l'attendre.
      final picked = await getIt<DonyMediaService>().pick(
        source: ImageSource.camera,
      );
      if (picked == null || !mounted) {
        if (mounted) _busy.value = _Busy.idle;
        return;
      }
      _busy.value = _Busy.locating;
      await _gpsFuture.timeout(_positionGrace, onTimeout: () {});
      if (!mounted) return;
      final position = _position.value;
      if (position != null) {
        await widget.locator.writeExif(picked.path, position);
      }
      if (!mounted) return;
      if (widget.returnResult) {
        if (await File(picked.path).length() > ScanPhotoScreen.maxPhotoBytes) {
          throw const MediaFileTooLargeException(
            ScanPhotoScreen.maxPhotoBytes + 1,
            ScanPhotoScreen.maxPhotoBytes,
          );
        }
        if (!mounted) return;
        context.pop(
          ScanPhotoResult(photoPath: picked.path, position: position),
        );
        return;
      }
      _busy.value = _Busy.idle;
      _navigateToConfirm(photoPath: picked.path);
    } on MediaFileTooLargeException catch (e) {
      if (!mounted) return;
      _busy.value = _Busy.idle;
      DonySnackbar.show(
        context,
        message: context.l10n.scanPhotoTooLarge(e.maxMb),
        type: DonySnackbarType.error,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      _busy.value = _Busy.idle;
      // Accès refusé dans les réglages : sans message, rien ne s'ouvrait.
      final denied = e.code == 'camera_access_denied';
      DonySnackbar.show(
        context,
        message: denied
            ? context.l10n.scanCameraAccessDenied
            : context.l10n.scanCameraUnavailable,
        type: DonySnackbarType.error,
        actionLabel: denied ? context.l10n.scanOpenSettings : null,
        onAction: denied ? () => unawaited(openSettings()) : null,
      );
    } catch (_) {
      if (mounted) _busy.value = _Busy.idle;
    }
  }

  /// Réglages de l'app, pour rendre l'accès à l'appareil photo.
  Future<bool> openSettings() => Geolocator.openAppSettings();

  void _skipPhoto() => _navigateToConfirm(photoPath: null);

  void _navigateToConfirm({required String? photoPath}) {
    context.push<void>(
      '/tracking/scan/confirm',
      extra: <String, dynamic>{
        'bidId': widget.bidId,
        'etape': widget.etape,
        'packageLabel': widget.packageLabel,
        'photoPath': photoPath,
        'gpsLat': _position.value?.lat,
        'gpsLon': _position.value?.lon,
        'gpsLabel': _position.value?.label,
        'scanMethod': widget.scanMethod,
        'deliveryWindow': widget.deliveryWindow,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final etapeIcons = _etapeIcons[widget.etape];
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
                child: widget.returnResult
                    ? _ResultHeader(
                        parcel: widget.packageLabel,
                        step: widget.etape,
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: l.commonClose,
                                icon: const DonyIcon(
                                  'x',
                                  color: DonyColors.neutral0,
                                ),
                                onPressed: () => context.pop(),
                              ),
                              Expanded(
                                child: Text(
                                  l.scanPhotoOfParcelLabel,
                                  textAlign: TextAlign.center,
                                  style: tt.bodyMedium?.copyWith(
                                    color: DonyColors.neutral0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const DonyFeedbackButton(
                                color: DonyColors.neutral0,
                              ),
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
                              color: DonyColors.neutral0.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(
                                DonyRadius.full,
                              ),
                              border: Border.all(
                                color: DonyColors.neutral0.withValues(
                                  alpha: 0.3,
                                ),
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
                          if (etapeIcons != null)
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
                                      if (etapeIcons.$2 != null)
                                        DonyIcon(
                                          etapeIcons.$2!,
                                          color: DonyColors.neutral0,
                                          size: 12,
                                        )
                                      else
                                        DonyIcon(
                                          etapeIcons.$1!,
                                          color: DonyColors.neutral0,
                                          size: 12,
                                        ),
                                      const SizedBox(width: DonySpacing.xs),
                                      Text(
                                        l.scanStepLabel(
                                          trackingStepLabel(l, widget.etape),
                                        ),
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
                                    color:
                                        (_photoRequired ? cs.error : cs.warning)
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
                                            ? l.scanPhotoMandatoryBadge
                                            : l.scanPhotoOptionalBadge,
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
                child: ValueListenableBuilder<_Busy>(
                  valueListenable: _busy,
                  builder: (context, busy, _) {
                    final loading = busy != _Busy.idle;
                    return Column(
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
                            label: Text(switch (busy) {
                              _Busy.idle => l.scanTakePhotoButton,
                              _Busy.opening => l.scanPhotoOpeningLoading,
                              _Busy.locating => l.scanPhotoLocating,
                            }),
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
                              child: Text(l.scanSkipPhotoButton),
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
                            Flexible(
                              child: ValueListenableBuilder<ScanPosition?>(
                                valueListenable: _position,
                                builder: (context, position, _) {
                                  final label = position?.label;
                                  return Text(
                                    widget.returnResult && label != null
                                        ? l.suiviPositionSaved(label)
                                        : l.scanAutoGeolocation,
                                    key: const Key('scan-photo-position'),
                                    textAlign: TextAlign.center,
                                    style: tt.labelSmall?.copyWith(
                                      color: DonyColors.neutral0.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Étape du bouton principal : repos, ouverture de l'appareil photo, puis
/// attente bornée de la position une fois la photo prise.
enum _Busy { idle, opening, locating }

/// En-tête du mode « retour de résultat » : « Photo du colis de X » et
/// l'étape qu'elle valide.
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.parcel, required this.step});

  final String parcel;
  final String step;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: l.commonClose,
          icon: const DonyIcon('x', color: DonyColors.neutral0),
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: DonySpacing.xs),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: DonySpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.suiviPhotoTitle(parcel),
                  style: tt.headlineSmall?.copyWith(
                    color: DonyColors.neutral0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  l.suiviPhotoRequiredFor(step),
                  style: tt.bodyMedium?.copyWith(
                    color: DonyColors.neutral0.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
        const DonyFeedbackButton(color: DonyColors.neutral0),
      ],
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
