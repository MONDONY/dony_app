import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/tracking/presentation/photo_dropped_warning.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/features/tracking/presentation/widgets/qr_camera_view.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  // ValueNotifier replaces setState for detected flag
  final _detectedNotifier = ValueNotifier<bool>(false);

  /// Caméra coupée : QR détecté (feuille ouverte) ou saisie manuelle.
  final _pausedNotifier = ValueNotifier<bool>(false);
  final _torchOn = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _detectedNotifier.dispose();
    _pausedNotifier.dispose();
    _torchOn.dispose();
    super.dispose();
  }

  // Les 3 points de reprise du scan (fermeture de sheet, de dialogue)
  // passent par ici ; QrCameraView gère lui-même la course start/stop.
  void _resumeScanning() => _pausedNotifier.value = false;

  void _onBidId(String bidId) {
    if (_detectedNotifier.value) return;
    _detectedNotifier.value = true;
    _pausedNotifier.value = true;
    _showScanSheet(bidId, ScanMethod.qr);
  }

  void _showScanSheet(
    String bidId,
    ScanMethod method, {
    String? trackingNumber,
  }) {
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
          scanMethod: method,
          trackingNumber: trackingNumber,
          onClose: () {
            _detectedNotifier.value = false;
            _resumeScanning();
          },
          onDeliveryConfirmed: (confirmedBidId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              RatingBottomSheet.show(
                context,
                bidId: confirmedBidId,
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
    final l = context.l10n;

    return BlocListener<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is QrScanSuccess) {
          if (state.photoDropped) warnTrackingPhotoDropped(context);
          context.pop(); // close sheet
          _showSuccessDialog(state.event.eventType, state.event.stepLabel(l));
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
              QrCameraView(
                onBidId: _onBidId,
                paused: _pausedNotifier,
                torchOn: _torchOn,
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
                        icon: const DonyIcon('x', color: DonyColors.white),
                        onPressed: () => context.pop(),
                        tooltip: l.commonClose,
                      ),
                      // Title centered
                      Expanded(
                        child: Text(
                          l.scanDepartureTitle,
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(
                            color: DonyColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Flash
                      QrTorchButton(torchOn: _torchOn),
                      const DonyFeedbackButton(color: DonyColors.white),
                    ],
                  ),
                ),
              ),

              // QR scanner frame (center)
              ValueListenableBuilder<bool>(
                valueListenable: _detectedNotifier,
                builder: (context, detected, _) {
                  return Center(child: QrScanFrame(detected: detected));
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
                    DonySpacing.base,
                    DonySpacing.base,
                    DonySpacing.base,
                    MediaQuery.of(context).padding.bottom + DonySpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step indicator
                      Text(
                        l.scanStepIndicatorStatic,
                        style: tt.labelSmall?.copyWith(
                          color: DonyColors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xs),
                      Text(
                        l.scanConfirmedInSuitcase,
                        style: tt.bodySmall?.copyWith(color: DonyColors.white),
                      ),
                      const SizedBox(height: DonySpacing.base),
                      // Action buttons
                      Row(
                        children: [
                          // Photo button (outlined white)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showManualEntryDialog,
                              icon: const DonyIcon(
                                'camera',
                                color: DonyColors.white,
                                size: 18,
                              ),
                              label: Text(
                                l.scanPhotoWordLabel,
                                style: tt.labelLarge?.copyWith(
                                  color: DonyColors.white,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: DonyColors.white,
                                side: const BorderSide(color: DonyColors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    DonyRadius.lg,
                                  ),
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
                              label: l.scanConfirmAndContinue,
                              iconAsset: 'check',
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
    final l = context.l10n;
    _pausedNotifier.value = true;
    final ctrl = TextEditingController();
    bool loading = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sheet),
          ),
          title: Text(
            l.scanTrackingNumberDialogTitle,
            style: tt.headlineMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.scanTrackingNumberDialogBody,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.md),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'DON-XXXXXX', // i18n-ignore: format de numéro
                  hintStyle: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  prefixIcon: DonyIcon('package', color: cs.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
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
                      _resumeScanning();
                    },
              child: Text(
                l.commonCancel,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
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
                          _pausedNotifier.value = true;
                          _showScanSheet(
                            result.bidId,
                            ScanMethod.manual,
                            trackingNumber: number,
                          );
                        }
                      } catch (_) {
                        setDialogState(() => loading = false);
                        // Le snackbar s'affiche sur l'écran, pas sur la boîte de
                        // dialogue : c'est donc `mounted` de l'State qu'il faut
                        // vérifier, pas celui de `ctx`.
                        if (mounted) {
                          DonySnackbar.show(
                            context,
                            message: l.scanNumberNotFound,
                            type: DonySnackbarType.error,
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
              ),
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : Text(l.commonConfirm, style: tt.labelLarge),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (!_detectedNotifier.value) _resumeScanning();
    });
  }

  void _showQueuedDialog() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.base),
              decoration: BoxDecoration(
                color: cs.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: DonyIcon('wifi-off', color: cs.warning, size: 40),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              l.scanQueuedTitle,
              style: tt.headlineMedium?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              l.scanQueuedNoConnectionBodyLong,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
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
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
              child: Text(l.scanUnderstoodButton, style: tt.labelLarge),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String eventType, String label) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final isFinal = isFinalDeliveryStep(eventType);
    final mascotteType = isFinal
        ? DonyMascotteType.securise
        : DonyMascotteType.confiant;
    final title = isFinal ? l.scanParcelDeliveredTitle : l.scanRecordedTitle;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyMascotteAnimated(
              type: mascotteType,
              size: DonyMascotteSize.lg,
              withGlow: isFinal,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              title,
              style: tt.headlineMedium?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
              child: Text(l.commonDone, style: tt.labelLarge),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renvoie true si le code d'étape correspond à une livraison finale.
///
/// Compare `eventType`, la donnée serveur (`DEPART`/`TRANSIT`/`ARRIVEE`),
/// jamais le libellé traduit affiché à l'écran.
bool isFinalDeliveryStep(String eventType) => eventType == 'ARRIVEE';

// ── Confirm bottom sheet ──────────────────────────────────────────────────────

class _ScanConfirmSheet extends StatefulWidget {
  final String bidId;

  /// QR lu par la caméra, ou numéro saisi à la main.
  final ScanMethod scanMethod;
  final VoidCallback onClose;
  final void Function(String bidId)? onDeliveryConfirmed;

  /// Numéro de suivi saisi pour identifier le colis (scan manuel) : il part
  /// avec la remise (DEPART), où le serveur le vérifie.
  final String? trackingNumber;

  const _ScanConfirmSheet({
    required this.bidId,
    required this.scanMethod,
    required this.onClose,
    this.onDeliveryConfirmed,
    this.trackingNumber,
  });

  @override
  State<_ScanConfirmSheet> createState() => _ScanConfirmSheetState();
}

class _ScanConfirmSheetState extends State<_ScanConfirmSheet> {
  String _eventType = 'DEPART'; // i18n-ignore: valeur de donnée (eventType)
  XFile? _photo;
  Position? _position;
  String? _gpsLabel;
  bool _loadingLocation = false;
  bool _photoTooBig = false;
  final _codeController = TextEditingController();

  // Codes + icônes uniquement : le libellé se calcule dans build() via
  // trackingStepLabel, jamais gardé en dur dans un champ de State.
  static const _eventTypes = <(String, String?, String?)>[
    ('DEPART', null, 'plane-takeoff'),
    ('TRANSIT', 'arrow-left-right', null),
    ('ARRIVEE', null, 'plane-landing'),
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
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
        }
      } catch (_) {}

      final picked = await getIt<DonyMediaService>().pick(
        source: ImageSource.camera,
      );

      if (picked != null && mounted) {
        if (pos != null) await _writeGpsExif(picked.path, pos);
        final gpsLabel = pos != null ? await _resolveGpsLabel(pos) : null;
        if (!mounted) return;
        setState(() {
          _photo = picked;
          _position = pos;
          _gpsLabel = gpsLabel;
          _loadingLocation = false;
        });
      } else {
        if (mounted) setState(() => _loadingLocation = false);
      }
    } on MediaFileTooLargeException catch (e) {
      if (mounted) {
        setState(() {
          _photoTooBig = true;
          _loadingLocation = false;
        });
        DonySnackbar.show(
          context,
          message: context.l10n.scanPhotoTooLarge(e.maxMb),
          type: DonySnackbarType.error,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _writeGpsExif(String path, Position pos) async {
    try {
      final exif = await Exif.fromPath(path);
      // Clés EXIF standard — jamais traduites (i18n-ignore).
      await exif.writeAttributes({
        'GPSLatitude': _toExifDms(pos.latitude.abs()), // i18n-ignore
        'GPSLatitudeRef': pos.latitude >= 0 ? 'N' : 'S', // i18n-ignore
        'GPSLongitude': _toExifDms(pos.longitude.abs()), // i18n-ignore
        'GPSLongitudeRef': pos.longitude >= 0 ? 'E' : 'W', // i18n-ignore
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

  Future<String?> _resolveGpsLabel(Position position) async {
    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isEmpty) return null;
      return _formatPlacemark(places.first);
    } catch (_) {
      return null;
    }
  }

  String? _formatPlacemark(Placemark place) {
    final parts = <String>[
      ?_cleanPlacePart(place.street),
      ?_cleanPlacePart(place.locality),
      ?_cleanPlacePart(place.administrativeArea),
      ?_cleanPlacePart(place.country),
    ];
    final unique = <String>[];
    for (final part in parts) {
      if (!unique.contains(part)) unique.add(part);
    }
    return unique.isEmpty ? null : unique.take(3).join(', ');
  }

  String? _cleanPlacePart(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _submit(BuildContext context) {
    if (_eventType == 'ARRIVEE') {
      final code = _codeController.text.trim();
      if (code.length != 6) return;
      context.read<TrackingBloc>().add(
        ConfirmDeliveryRequested(
          bidId: widget.bidId,
          code: code,
          photo: _photo,
          scanMethod: widget.scanMethod,
          gpsLat: _position?.latitude,
          gpsLon: _position?.longitude,
          gpsLabel: _gpsLabel,
        ),
      );
    } else {
      context.read<TrackingBloc>().add(
        QrScanSubmitRequested(
          bidId: widget.bidId,
          eventType: _eventType,
          photo: _photo,
          gpsLat: _position?.latitude,
          gpsLon: _position?.longitude,
          gpsLabel: _gpsLabel,
          scanMethod: widget.scanMethod,
          trackingNumber: _eventType == 'DEPART' ? widget.trackingNumber : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
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
            if (state.photoDropped) warnTrackingPhotoDropped(context);
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
                    child: Text(l.scanQrReadTitle, style: tt.headlineMedium),
                  ),
                  if (!isSubmitting)
                    IconButton(
                      tooltip: l.commonClose,
                      icon: DonyIcon('x', color: cs.onSurfaceVariant),
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
                l.scanEventTypeSectionLabel,
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
                          vertical: DonySpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(DonyRadius.md),
                          border: Border.all(
                            color: isSelected ? cs.primary : cs.outline,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (type.$3 != null)
                              DonyIcon(
                                type.$3!,
                                color: isSelected
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                                size: 20,
                              )
                            else
                              DonyIcon(
                                type.$2!,
                                color: isSelected
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                                size: 20,
                              ),
                            const SizedBox(height: DonySpacing.xs),
                            Text(
                              trackingStepLabel(l, type.$1),
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
                  l.scanConfirmationCodeLabel,
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
                      DonyIcon('info', color: cs.primary, size: 15),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          l.scanConfirmationCodeHintLong,
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
                      borderSide: BorderSide(color: cs.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: DonySpacing.base,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  l.scanPhotoOfParcelLabel,
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
                                  color: cs.primary,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DonyIcon(
                                    'camera',
                                    color: cs.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: DonySpacing.sm),
                                  Text(
                                    l.commonTakePhoto,
                                    style: tt.titleSmall?.copyWith(
                                      color: cs.primary,
                                    ),
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
                          errorBuilder: (_, _, _) => Container(
                            height: 120,
                            color: cs.primaryContainer,
                            child: Center(
                              child: DonyIcon(
                                'image',
                                color: cs.primary,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!isSubmitting)
                        Positioned(
                          top: DonySpacing.sm,
                          right: DonySpacing.sm,
                          child: Semantics(
                            button: true,
                            container: true,
                            excludeSemantics: true,
                            label: l.scanRemovePhotoSemantics,
                            child: GestureDetector(
                              onTap: () => setState(() => _photo = null),
                              child: Container(
                                padding: const EdgeInsets.all(DonySpacing.xs),
                                decoration: BoxDecoration(
                                  color: DonyColors.ink900.withValues(
                                    alpha: 0.54,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const DonyIcon(
                                  'x',
                                  color: DonyColors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                if (_position != null) ...[
                  const SizedBox(height: DonySpacing.sm),
                  Row(
                    children: [
                      DonyIcon('map-pin', color: cs.success, size: 14),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        _gpsLabel?.trim().isNotEmpty == true
                            ? _gpsLabel!.trim()
                            : l.scanGpsLocationSaved,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_photoTooBig) ...[
                  const SizedBox(height: DonySpacing.sm),
                  Row(
                    children: [
                      DonyIcon('triangle-alert', color: cs.error, size: 14),
                      const SizedBox(width: DonySpacing.xs),
                      Expanded(
                        child: Text(
                          l.scanPhotoTooLargeFixed,
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
                    ? (isArrivee
                          ? l.scanSubmittingConfirmation
                          : l.scanSubmittingRecording)
                    : (isArrivee
                          ? l.scanConfirmDeliveryButton
                          : l.scanConfirmReadingLabel),
                iconAsset: isArrivee ? 'badge-check' : 'check',
                onPressed: isSubmitting ? null : () => _submit(context),
                isLoading: isSubmitting,
              ),

              if (state is QrScanError || state is DeliveryConfirmError) ...[
                const SizedBox(height: DonySpacing.md),
                Text(
                  state is QrScanError
                      ? ErrorPresenter.resolve(
                          state.error,
                          l10n: context.l10n,
                        ).message
                      : ErrorPresenter.resolve(
                          (state as DeliveryConfirmError).error,
                          l10n: context.l10n,
                        ).message,
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
