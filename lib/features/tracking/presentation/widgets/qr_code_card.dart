import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class QrCodeCard extends StatefulWidget {
  final String bidId;

  const QrCodeCard({super.key, required this.bidId});

  @override
  State<QrCodeCard> createState() => _QrCodeCardState();
}

class _QrCodeCardState extends State<QrCodeCard> {
  @override
  void initState() {
    super.initState();
    context.read<TrackingBloc>().add(TrackingQrCodeRequested(widget.bidId));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QR Code de suivi',
            style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DonyColors.grey400,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          BlocBuilder<TrackingBloc, TrackingState>(
            builder: (context, state) {
              if (state is TrackingQrLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: DonyColors.blue400),
                  ),
                );
              }
              if (state is TrackingQrError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: DonyColors.error, size: 18),
                      const SizedBox(width: 8),
                      Text(state.message,
                          style: GoogleFonts.sora(
                              fontSize: 13, color: DonyColors.error)),
                    ],
                  ),
                );
              }
              if (state is TrackingQrLoaded) {
                return _QrCodeContent(qrCode: state.qrCode)
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutCubic);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class _QrCodeContent extends StatelessWidget {
  final QrCodeModel qrCode;

  const _QrCodeContent({required this.qrCode});

  @override
  Widget build(BuildContext context) {
    final Uint8List imageBytes = base64Decode(qrCode.qrCodeBase64);

    return Column(
      children: [
        // QR Image
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DonyColors.grey100),
          ),
          padding: const EdgeInsets.all(12),
          child: Image.memory(
            imageBytes,
            width: double.infinity,
            height: 220,
            fit: BoxFit.contain,
          ),
        ),

        const SizedBox(height: 12),

        // Instruction
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DonyColors.blue100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: DonyColors.blue400, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Montrez ce QR code au voyageur lors de la remise du colis. Il le scannera pour valider la prise en charge.',
                  style: GoogleFonts.sora(
                      fontSize: 12,
                      color: DonyColors.blue600,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            // Enregistrer dans la galerie — reste dans l'app
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _saveToGallery(context, imageBytes),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  'Enregistrer',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DonyColors.blue400,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Partager — quitte l'app vers WhatsApp etc.
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareQrCode(context, imageBytes),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: Text(
                  'Partager',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DonyColors.blue400,
                  side: const BorderSide(color: DonyColors.blue400),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveToGallery(BuildContext context, Uint8List imageBytes) async {
    try {
      await Gal.putImageBytes(imageBytes, name: 'qr_dony.png');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR code enregistré dans votre galerie',
                style: GoogleFonts.sora(fontWeight: FontWeight.w500)),
            backgroundColor: DonyColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'enregistrer : $e',
                style: GoogleFonts.sora(fontWeight: FontWeight.w500)),
            backgroundColor: DonyColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _shareQrCode(BuildContext context, Uint8List imageBytes) async {
    try {
      // XFile.fromData ne fonctionne pas sur Android avec la plupart des apps.
      // On écrit d'abord dans un fichier temporaire pour obtenir un vrai chemin.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_dony_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path, name: 'qr_dony.png', mimeType: 'image/png')],
        text: 'QR code de suivi Dony — À montrer au voyageur lors de la remise.',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de partager : $e',
                style: GoogleFonts.sora(fontWeight: FontWeight.w500)),
            backgroundColor: DonyColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}
