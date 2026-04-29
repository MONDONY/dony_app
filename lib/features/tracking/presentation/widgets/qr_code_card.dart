import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QR Code de suivi',
            style: tt.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          BlocBuilder<TrackingBloc, TrackingState>(
            builder: (context, state) {
              if (state is TrackingQrLoading) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: cs.primary),
                  ),
                );
              }
              if (state is TrackingQrError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
                      const SizedBox(width: DonySpacing.sm),
                      Text(state.message,
                          style: tt.bodySmall?.copyWith(color: cs.error)),
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final Uint8List imageBytes = base64Decode(qrCode.qrCodeBase64);

    return Column(
      children: [
        // QR Image
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: cs.outline),
          ),
          padding: const EdgeInsets.all(DonySpacing.md),
          child: Image.memory(
            imageBytes,
            width: double.infinity,
            height: 220,
            fit: BoxFit.contain,
          ),
        ),

        const SizedBox(height: DonySpacing.md),

        // Instruction
        Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: cs.primary, size: 16),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  'Montrez ce QR code au voyageur lors de la remise du colis. Il le scannera pour valider la prise en charge.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: DonySpacing.md),

        Row(
          children: [
            Expanded(
              child: DonyButton(
                label: 'Enregistrer',
                onPressed: () => _saveToGallery(context, imageBytes),
                icon: Icons.download_rounded,
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: DonyButton(
                label: 'Partager',
                onPressed: () => _shareQrCode(context, imageBytes),
                variant: DonyButtonVariant.secondary,
                icon: Icons.share_rounded,
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
        DonySnackbar.show(
          context,
          message: 'QR code enregistré dans votre galerie',
          type: DonySnackbarType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        DonySnackbar.show(
          context,
          message: 'Impossible d\'enregistrer : $e',
          type: DonySnackbarType.error,
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
        DonySnackbar.show(
          context,
          message: 'Impossible de partager : $e',
          type: DonySnackbarType.error,
        );
      }
    }
  }
}
