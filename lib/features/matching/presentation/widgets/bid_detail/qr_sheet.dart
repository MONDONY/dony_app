import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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

    // ValueNotifiers pour l'état loading des boutons (pas de setState)
    final saving = ValueNotifier<bool>(false);
    final sharing = ValueNotifier<bool>(false);

    await DonyBottomSheet.show<void>(
      context,
      title: 'QR du colis',
      wrapper: (child) => BlocProvider<TrackingBloc>(
        create: (_) =>
            (trackingBlocFactory?.call() ?? GetIt.instance<TrackingBloc>())
              ..add(TrackingQrCodeRequested(bidId)),
        child: child,
      ),
      child: const _QrSheetBody(),
      stickyBottom: _QrSheetStickyBottom(
        bidId: bidId,
        saving: saving,
        sharing: sharing,
      ),
    ).whenComplete(() {
      // Réinitialise la luminosité à la fermeture — best-effort
      try {
        ScreenBrightness.instance.resetApplicationScreenBrightness();
      } catch (_) {}
      saving.dispose();
      sharing.dispose();
    });
  }
}

// ── Body (contenu pur — aucun DonyButton) ─────────────────────────────────────

class _QrSheetBody extends StatelessWidget {
  const _QrSheetBody();

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
          return _QrErrorView(state: state);
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

// ── StickyBottom — boutons selon l'état BLoC ──────────────────────────────────

class _QrSheetStickyBottom extends StatelessWidget {
  const _QrSheetStickyBottom({
    required this.bidId,
    required this.saving,
    required this.sharing,
  });

  final String bidId;
  final ValueNotifier<bool> saving;
  final ValueNotifier<bool> sharing;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackingBloc, TrackingState>(
      builder: (context, state) {
        if (state is TrackingQrError) {
          return DonyButton(
            label: 'Réessayer',
            variant: DonyButtonVariant.secondary,
            onPressed: () {
              context.read<TrackingBloc>().add(TrackingQrCodeRequested(bidId));
            },
          );
        }

        if (state is TrackingQrLoaded) {
          final imageBytes = base64Decode(state.qrCode.qrCodeBase64);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Save button
              ValueListenableBuilder<bool>(
                valueListenable: saving,
                builder: (context, isSaving, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: sharing,
                    builder: (context, isSharing, _) {
                      return DonyButton(
                        label: 'Enregistrer',
                        iconAsset: 'download',
                        isLoading: isSaving,
                        onPressed: (isSaving || isSharing)
                            ? null
                            : () => _saveToGallery(context, imageBytes),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: DonySpacing.sm),
              // Share button
              ValueListenableBuilder<bool>(
                valueListenable: saving,
                builder: (context, isSaving, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: sharing,
                    builder: (context, isSharing, _) {
                      return DonyButton(
                        label: 'Partager',
                        variant: DonyButtonVariant.secondary,
                        iconAsset: 'share-2',
                        isLoading: isSharing,
                        onPressed: (isSaving || isSharing)
                            ? null
                            : () => _shareQrCode(context, imageBytes),
                      );
                    },
                  );
                },
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _saveToGallery(
    BuildContext context,
    Uint8List imageBytes,
  ) async {
    saving.value = true;
    try {
      await Gal.putImageBytes(imageBytes, name: 'qr_dony.png');
      unawaited(
        getItSafe<AnalyticsService>()?.logEvent(
          AnalyticsEvents.bidQrDownloaded,
          properties: {'action': 'save'},
        ),
      );
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
          message: 'Impossible d\'enregistrer l\'image',
          type: DonySnackbarType.error,
        );
      }
    } finally {
      // Guard against use-after-dispose: the notifier is disposed when the
      // sheet closes; if the user dismissed while this await was in flight
      // the context is no longer mounted.
      if (context.mounted) {
        saving.value = false;
      }
    }
  }

  Future<void> _shareQrCode(BuildContext context, Uint8List imageBytes) async {
    sharing.value = true;
    // Calculé avant tout await : sharePositionOriginFor lit le RenderBox
    // du context, qui peut être démonté pendant les opérations async.
    final origin = sharePositionOriginFor(context);
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/qr_dony_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'QR du colis Yadony',
        text: 'QR à présenter ou à coller sur le colis.',
        sharePositionOrigin: origin,
      );
      // Only log if the user actually shared (not dismissed)
      if (result.status != ShareResultStatus.dismissed) {
        unawaited(
          getItSafe<AnalyticsService>()?.logEvent(
            AnalyticsEvents.bidQrDownloaded,
            properties: {'action': 'share'},
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        DonySnackbar.show(
          context,
          message: 'Impossible de partager le QR code',
          type: DonySnackbarType.error,
        );
      }
    } finally {
      // Guard against use-after-dispose: the notifier is disposed when the
      // sheet closes; if the user dismissed while this await was in flight
      // the context is no longer mounted.
      if (context.mounted) {
        sharing.value = false;
      }
    }
  }
}

// ── Error view (contenu pur — aucun DonyButton) ───────────────────────────────

class _QrErrorView extends StatelessWidget {
  const _QrErrorView({required this.state});

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
          DonyIcon('circle-alert', color: cs.error, size: 48),
          const SizedBox(height: DonySpacing.md),
          Text(
            presentation.message,
            style: tt.bodyMedium?.copyWith(color: cs.error),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Loaded view (contenu pur — aucun DonyButton) ──────────────────────────────

class _QrLoadedView extends StatelessWidget {
  const _QrLoadedView({required this.state});

  final TrackingQrLoaded state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final Uint8List imageBytes = base64Decode(state.qrCode.qrCodeBase64);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instruction text
        Text(
          'Lu par le voyageur à la remise, puis à chaque étape jusqu\'au '
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
            child:
                Image.memory(
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

        const SizedBox(height: DonySpacing.base),
      ],
    );
  }
}
