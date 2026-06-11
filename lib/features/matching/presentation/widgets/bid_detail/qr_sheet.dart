import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// GetIt lookup that tolerates missing registrations. Returns `null` if
/// [T] is not registered, making analytics best-effort in contexts that
/// don't wire up the full DI graph (tests, preview widgets, etc.).
T? getItSafe<T extends Object>() {
  try {
    return GetIt.instance<T>();
  } catch (_) {
    return null;
  }
}

// ── QrSheet ───────────────────────────────────────────────────────────────────

/// Bottom sheet affichant le QR code du colis pour l'expéditeur.
///
/// Ouvre un [DonyBottomSheet] avec luminosité maximale et réinitialisation
/// automatique à la fermeture.
///
/// Le [trackingBlocFactory] est injecté pour les tests ; en production le
/// BLoC est résolu via GetIt.
abstract final class QrSheet {
  static Future<void> show(
    BuildContext context, {
    required String bidId,
    required String status,
    TrackingBloc Function()? trackingBlocFactory,
  }) async {
    // Haptic feedback best-effort (non-blocking)
    unawaited(HapticFeedback.lightImpact().catchError((_) {}));

    // Analytics best-effort
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.bidQrSheetOpened,
        properties: {'status': status},
      ),
    );

    // Luminosité maximale — best-effort (non-blocking)
    unawaited(
      ScreenBrightness.instance
          .setApplicationScreenBrightness(1.0)
          .catchError((_) {}),
    );

    await DonyBottomSheet.show<void>(
      context,
      title: 'QR du colis',
      wrapper: (child) => BlocProvider<TrackingBloc>(
        create: (_) =>
            (trackingBlocFactory?.call() ?? GetIt.instance<TrackingBloc>())
              ..add(TrackingQrCodeRequested(bidId)),
        child: child,
      ),
      child: _QrSheetBody(bidId: bidId),
    ).whenComplete(() {
      // Réinitialise la luminosité à la fermeture — best-effort
      try {
        ScreenBrightness.instance.resetApplicationScreenBrightness();
      } catch (_) {}
    });
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _QrSheetBody extends StatelessWidget {
  const _QrSheetBody({required this.bidId});

  final String bidId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<TrackingBloc, TrackingState>(
      builder: (context, state) {
        if (state is TrackingQrLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.huge),
              child: CircularProgressIndicator(color: cs.primary),
            ),
          );
        }

        if (state is TrackingQrError) {
          return _QrErrorView(bidId: bidId, state: state);
        }

        if (state is TrackingQrLoaded) {
          return _QrLoadedView(state: state);
        }

        // Initial / unknown state — show spinner as fallback
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.huge),
            child: CircularProgressIndicator(color: cs.primary),
          ),
        );
      },
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _QrErrorView extends StatelessWidget {
  const _QrErrorView({required this.bidId, required this.state});

  final String bidId;
  final TrackingQrError state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final presentation = ErrorPresenter.resolve(state.error);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 48),
          const SizedBox(height: DonySpacing.md),
          Text(
            presentation.message,
            style: tt.bodyMedium?.copyWith(color: cs.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyButton(
            label: 'Réessayer',
            variant: DonyButtonVariant.secondary,
            onPressed: () {
              context
                  .read<TrackingBloc>()
                  .add(TrackingQrCodeRequested(bidId));
            },
          ),
        ],
      ),
    );
  }
}

// ── Loaded view ───────────────────────────────────────────────────────────────

class _QrLoadedView extends StatefulWidget {
  const _QrLoadedView({required this.state});

  final TrackingQrLoaded state;

  @override
  State<_QrLoadedView> createState() => _QrLoadedViewState();
}

class _QrLoadedViewState extends State<_QrLoadedView> {
  bool _saving = false;
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final Uint8List imageBytes =
        base64Decode(widget.state.qrCode.qrCodeBase64);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instruction text
        Text(
          'Scanné par le voyageur à la remise, puis à chaque étape jusqu\'au '
          'retrait. Vous pouvez aussi l\'imprimer et le coller sur le colis.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: DonySpacing.xl),

        // QR image
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(color: cs.outline),
            ),
            padding: const EdgeInsets.all(DonySpacing.md),
            child: Image.memory(
              imageBytes,
              width: 240,
              height: 240,
              fit: BoxFit.contain,
            )
                .animate()
                .fadeIn(duration: 250.ms)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  curve: Curves.easeOutCubic,
                ),
          ),
        ),

        const SizedBox(height: DonySpacing.xl),

        // Save button
        DonyButton(
          label: 'Enregistrer',
          icon: Icons.download_rounded,
          isLoading: _saving,
          onPressed:
              (_saving || _sharing) ? null : () => _saveToGallery(imageBytes),
        ),

        const SizedBox(height: DonySpacing.sm),

        // Share button
        DonyButton(
          label: 'Partager',
          variant: DonyButtonVariant.secondary,
          icon: Icons.share_rounded,
          isLoading: _sharing,
          onPressed:
              (_saving || _sharing) ? null : () => _shareQrCode(imageBytes),
        ),

        const SizedBox(height: DonySpacing.base),
      ],
    );
  }

  Future<void> _saveToGallery(Uint8List imageBytes) async {
    setState(() => _saving = true);
    try {
      await Gal.putImageBytes(imageBytes, name: 'qr_dony.png');
      unawaited(
        getItSafe<AnalyticsService>()?.logEvent(
          AnalyticsEvents.bidQrDownloaded,
        ),
      );
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'QR code enregistré dans votre galerie',
          type: DonySnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Impossible d\'enregistrer l\'image',
          type: DonySnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _shareQrCode(Uint8List imageBytes) async {
    setState(() => _sharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/qr_dony_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'QR du colis Dony',
        text: 'QR à présenter ou à coller sur le colis.',
      );
      unawaited(
        getItSafe<AnalyticsService>()?.logEvent(
          AnalyticsEvents.bidQrDownloaded,
        ),
      );
    } catch (e) {
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Impossible de partager le QR code',
          type: DonySnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }
}
