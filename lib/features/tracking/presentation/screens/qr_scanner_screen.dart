import 'dart:io';

import 'package:dony/app/theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _detected = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final bidId = _extractBidId(raw);
    if (bidId == null) return;

    setState(() => _detected = true);
    _scanner.stop();
    _showScanSheet(bidId);
  }

  String? _extractBidId(String raw) {
    // URL format: .../tracking/{bidId}/scan
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final idx = segments.indexOf('tracking');
    if (idx == -1 || idx + 1 >= segments.length) return null;
    final candidate = segments[idx + 1];
    // Basic UUID check
    final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    return uuidPattern.hasMatch(candidate) ? candidate : null;
  }

  void _showScanSheet(String bidId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<TrackingBloc>(),
        child: _ScanConfirmSheet(
          bidId: bidId,
          onClose: () {
            setState(() => _detected = false);
            _scanner.start();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is QrScanSuccess) {
          Navigator.of(context).pop(); // close sheet
          _showSuccessDialog(state.event.stepLabel);
        } else if (state is QrScanQueued) {
          Navigator.of(context).pop(); // close sheet
          _showQueuedDialog();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Scanner le QR code',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.keyboard_rounded, color: Colors.white),
              tooltip: 'Saisir le numéro manuellement',
              onPressed: _showManualEntryDialog,
            ),
            IconButton(
              icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
              onPressed: () => _scanner.toggleTorch(),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _scanner,
              onDetect: _onDetect,
            ),
            _ScanFrame(),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    'Pointez la caméra vers le QR code du colis',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showManualEntryDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.keyboard_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Saisir le numéro manuellement',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    _scanner.stop();
    final ctrl = TextEditingController();
    bool loading = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Numéro de suivi',
            style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entrez le numéro DON-XXXXXX du colis à scanner.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'DON-XXXXXX',
                  hintStyle: GoogleFonts.plusJakartaSans(color: kTextHint),
                  prefixIcon: const Icon(Icons.local_shipping_outlined, color: kGreenPrimary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kGreenPrimary, width: 2),
                  ),
                ),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      _scanner.start();
                    },
              child: Text('Annuler',
                  style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
            ),
            ElevatedButton(
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
                          Navigator.of(ctx).pop();
                          setState(() => _detected = true);
                          _showScanSheet(result.bidId);
                        }
                      } catch (_) {
                        setDialogState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Numéro introuvable. Vérifiez et réessayez.',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
                              ),
                              backgroundColor: kError,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreenPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Confirmer',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Si fermé sans confirmer, relance le scanner
      if (!_detected) _scanner.start();
    });
  }

  void _showQueuedDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWarning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: kWarning, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan en attente',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Pas de connexion internet. Le scan sera synchronisé automatiquement dès que vous serez en ligne.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: kTextSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kWarning,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Compris',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String label) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: kSuccess, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan enregistré !',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextSecondary),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreenPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Terminé',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scan frame overlay ────────────────────────────────────────────────────────

class _ScanFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          children: [
            // corners
            for (final pos in [
              Alignment.topLeft,
              Alignment.topRight,
              Alignment.bottomLeft,
              Alignment.bottomRight,
            ])
              Align(alignment: pos, child: _Corner(alignment: pos)),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final Alignment alignment;
  const _Corner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;

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
      ..color = kGreenPrimary
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

  const _ScanConfirmSheet({required this.bidId, required this.onClose});

  @override
  State<_ScanConfirmSheet> createState() => _ScanConfirmSheetState();
}

class _ScanConfirmSheetState extends State<_ScanConfirmSheet> {
  String _eventType = 'DEPART';
  XFile? _photo;
  Position? _position;
  bool _loadingLocation = false;
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
    setState(() => _loadingLocation = true);
    try {
      // Get GPS before opening camera
      Position? pos;
      try {
        final permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        }
      } catch (_) {}

      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 85, maxWidth: 1920, maxHeight: 1080);

      if (picked != null && mounted) {
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
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
      child: BlocConsumer<TrackingBloc, TrackingState>(
        listener: (context, state) {
          if (state is DeliveryConfirmSuccess || state is QrScanSuccess || state is QrScanQueued) {
            Navigator.pop(context);
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
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration:
                      BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: Text('QR scanné',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
                  ),
                  if (!isSubmitting)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: kTextSecondary),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onClose();
                      },
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Event type selector
              Text('Type d\'étape',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: kTextSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Row(
                children: _eventTypes.map((type) {
                  final isSelected = _eventType == type.$1;
                  return Expanded(
                    child: GestureDetector(
                      onTap: isSubmitting ? null : () => setState(() => _eventType = type.$1),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? kGreenPrimary : kBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isSelected ? kGreenPrimary : kBorder, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Icon(type.$3,
                                color: isSelected ? Colors.white : kTextSecondary, size: 20),
                            const SizedBox(height: 4),
                            Text(type.$2,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : kTextSecondary)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ARRIVEE : code input — Photo : DEPART / TRANSIT
              if (isArrivee) ...[
                Text('Code de confirmation',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: kTextSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kGreenLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: kGreenPrimary, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demandez le code à 6 chiffres au destinataire. Il l\'a reçu de l\'expéditeur.',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: kGreenDark, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 10),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '------',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 28, color: kBorder, letterSpacing: 10),
                    filled: true,
                    fillColor: kBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGreenPrimary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ] else ...[
                Text('Photo du colis',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: kTextSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 10),

                if (_photo == null)
                  GestureDetector(
                    onTap: isSubmitting || _loadingLocation ? null : _pickPhoto,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: kBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: Center(
                        child: _loadingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: kGreenPrimary))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.camera_alt_rounded,
                                      color: kGreenPrimary, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Prendre une photo',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: kGreenPrimary)),
                                ],
                              ),
                      ),
                    ),
                  )
                else
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_photo!.path),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: kGreenLight,
                            child: const Center(
                                child: Icon(Icons.image_rounded,
                                    color: kGreenPrimary, size: 32)),
                          ),
                        ),
                      ),
                      if (!isSubmitting)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _photo = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                    ],
                  ),

                if (_position != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: kSuccess, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'GPS : ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: kTextSecondary),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : () => _submit(context),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(isArrivee
                          ? Icons.verified_rounded
                          : Icons.check_rounded),
                  label: Text(
                    isSubmitting
                        ? (isArrivee ? 'Confirmation...' : 'Enregistrement...')
                        : (isArrivee ? 'Confirmer la livraison' : 'Confirmer le scan'),
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isArrivee ? kSuccess : kGreenPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              if (state is QrScanError || state is DeliveryConfirmError) ...[
                const SizedBox(height: 12),
                Text(
                  state is QrScanError
                      ? state.message
                      : (state as DeliveryConfirmError).message,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: kError, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
