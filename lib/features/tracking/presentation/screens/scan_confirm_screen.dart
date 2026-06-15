import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

const _etapeLabels = <String, (String, String?, String?)>{
  'DEPART': ('Départ', null, 'plane-takeoff'),
  'TRANSIT': ('Transit', 'arrow-left-right', null),
  'ARRIVEE': ('Arrivée', null, 'plane-landing'),
};

class ScanConfirmScreen extends StatefulWidget {
  const ScanConfirmScreen({
    super.key,
    required this.bidId,
    required this.etape,
    required this.packageLabel,
    this.photoPath,
    this.gpsLat,
    this.gpsLon,
  });

  final String bidId;
  final String etape;
  final String packageLabel;
  final String? photoPath;
  final double? gpsLat;
  final double? gpsLon;

  @override
  State<ScanConfirmScreen> createState() => _ScanConfirmScreenState();
}

class _ScanConfirmScreenState extends State<ScanConfirmScreen> {
  final TextEditingController _codeCtrl = TextEditingController();

  bool get _isArrivee => widget.etape == 'ARRIVEE';

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_isArrivee) {
      final code = _codeCtrl.text.trim();
      if (code.length != 6) return;
      context.read<TrackingBloc>().add(
            ConfirmDeliveryRequested(bidId: widget.bidId, code: code),
          );
    } else {
      final photo =
          widget.photoPath != null ? XFile(widget.photoPath!) : null;
      context.read<TrackingBloc>().add(QrScanSubmitRequested(
            bidId: widget.bidId,
            eventType: widget.etape,
            photo: photo,
            gpsLat: widget.gpsLat,
            gpsLon: widget.gpsLon,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final etapeInfo = _etapeLabels[widget.etape];
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return BlocConsumer<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is QrScanSuccess) {
          _showSuccess(context, state.event.stepLabel, isFinal: false);
        } else if (state is QrScanQueued) {
          _showQueued(context);
        } else if (state is DeliveryConfirmSuccess) {
          _showSuccess(
            context,
            state.event.stepLabel,
            isFinal: true,
            finalBidId: state.event.bidId,
          );
        }
      },
      builder: (context, state) {
        final isSubmitting =
            state is QrScanSubmitting || state is DeliveryConfirmLoading;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            title: Text('Confirmer le scan', style: tt.headlineLarge),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: cs.outline),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              bottomPad + DonySpacing.huge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chip étape
                if (etapeInfo != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: switch (etapeInfo.$3) {
                        'plane-takeoff' => const DonyEmoji.planeTakeoff(size: 14),
                        'plane-landing' => const DonyEmoji.planeLanding(size: 14),
                        _ => DonyIcon(etapeInfo.$2!, size: 14, color: cs.primary),
                      },
                      label: Text('${etapeInfo.$1} enregistrée'),
                      labelStyle: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      backgroundColor: cs.primaryContainer,
                      side: BorderSide.none,
                    ),
                  ),

                const SizedBox(height: DonySpacing.base),

                // Carte recap
                DonyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Miniature photo
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(DonyRadius.card),
                        ),
                        child: widget.photoPath != null
                            ? Image.file(
                                File(widget.photoPath!),
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _PhotoPlaceholder(),
                              )
                            : _PhotoPlaceholder(),
                      ),
                      // Lignes méta
                      Padding(
                        padding: const EdgeInsets.all(DonySpacing.base),
                        child: Column(
                          children: [
                            _MetaRow(
                              label: 'Colis',
                              value: widget.packageLabel,
                            ),
                            const Divider(height: DonySpacing.base),
                            _MetaRow(
                              label: 'Étape',
                              value: etapeInfo != null
                                  ? etapeInfo.$1
                                  : widget.etape,
                            ),
                            if (widget.gpsLat != null &&
                                widget.gpsLon != null) ...[
                              const SizedBox(height: DonySpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DonySpacing.sm,
                                  vertical: DonySpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(DonyRadius.sm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DonyIcon('map-pin',
                                        color: cs.primary, size: 13),
                                    const SizedBox(width: DonySpacing.xs),
                                    Text(
                                      '${widget.gpsLat!.toStringAsFixed(4)}, ${widget.gpsLon!.toStringAsFixed(4)}',
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: DonySpacing.lg),

                // Champ code pour ARRIVEE
                if (_isArrivee) ...[
                  Container(
                    padding: const EdgeInsets.all(DonySpacing.sm),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DonyIcon('info',
                            color: cs.primary, size: 15),
                        const SizedBox(width: DonySpacing.sm),
                        Expanded(
                          child: Text(
                            'Demandez le code à 6 chiffres au destinataire.',
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
                    controller: _codeCtrl,
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
                  const SizedBox(height: DonySpacing.xl),
                ],

                // Bouton principal
                DonyButton(
                  label: _isArrivee ? 'Confirmer la livraison' : 'Valider le scan',
                  iconAsset: _isArrivee ? 'badge-check' : 'check',
                  onPressed: isSubmitting ? null : () => _submit(context),
                  isLoading: isSubmitting,
                ),

                const SizedBox(height: DonySpacing.sm),

                // Reprendre photo
                if (widget.photoPath != null)
                  TextButton.icon(
                    onPressed: isSubmitting ? null : () => context.pop(),
                    icon: DonyIcon('refresh-cw',
                        size: 16, color: cs.onSurfaceVariant),
                    label: const Text('Reprendre la photo'),
                    style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant),
                  ),

                // Message d'erreur
                if (state is QrScanError || state is DeliveryConfirmError) ...[
                  const SizedBox(height: DonySpacing.md),
                  Text(
                    state is QrScanError
                        ? ErrorPresenter.resolve(state.error).message
                        : ErrorPresenter.resolve(
                                (state as DeliveryConfirmError).error)
                            .message,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.error, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccess(
    BuildContext context,
    String label, {
    required bool isFinal,
    String? finalBidId,
  }) {
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
              type: isFinal
                  ? DonyMascotteType.securise
                  : DonyMascotteType.confiant,
              size: DonyMascotteSize.lg,
              withGlow: isFinal,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              isFinal ? 'Colis livré !' : 'Scan enregistré !',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                ctx.pop();
                if (isFinal && finalBidId != null) {
                  await RatingBottomSheet.show(
                    context,
                    bidId: finalBidId,
                    travelerName: "l'expéditeur",
                    isTravelerRating: true,
                  );
                }
                if (context.mounted) context.go('/tracking');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
              child: const Text('Terminé'),
            ),
          ),
        ],
      ),
    );
  }

  void _showQueued(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              'Scan en attente',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Pas de connexion. Le scan sera synchronisé dès que vous serez en ligne.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                context.go('/tracking');
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.warning,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
              child: const Text('Compris'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      color: cs.surfaceContainerHighest,
      child: Center(
        child: DonyIcon('camera',
            color: cs.onSurfaceVariant, size: 32),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        Text(value,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
