import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/presentation/photo_dropped_warning.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:dony/features/tracking/presentation/widgets/pickup_code_request_panel.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

// Icônes uniquement : le libellé se calcule via trackingStepLabel.
const _etapeIcons = <String, (String?, String?)>{
  'DEPART': (null, 'plane-takeoff'),
  'TRANSIT': ('arrow-left-right', null),
  'ARRIVEE': (null, 'plane-landing'),
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
    this.gpsLabel,
    this.scanMethod,
    this.deliveryWindow,
  });

  final String bidId;
  final String etape;
  final String packageLabel;
  final String? photoPath;
  final double? gpsLat;
  final double? gpsLon;
  final String? gpsLabel;

  /// Provenance envoyée au back ; `null` : rien n'est envoyé.
  final ScanMethod? scanMethod;

  /// Départ du trajet (ARRIVEE) : le bouton reste désactivé tant qu'il n'est
  /// pas atteint (422 `trip-not-departed`, FLUTTER-CB). `null` : inconnu, le
  /// serveur tranche.
  final DeliveryWindow? deliveryWindow;

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
    final photo = widget.photoPath != null ? XFile(widget.photoPath!) : null;
    if (_isArrivee) {
      final code = _codeCtrl.text.trim();
      // Le bouton ne réagissait pas à un code incomplet, sans un mot : le
      // voyageur concluait que le code ne marchait pas (FLUTTER-BA).
      if (code.length != 6) {
        DonySnackbar.show(
          context,
          message: context.l10n.scanConfirmCodeIncomplete,
        );
        return;
      }
      context.read<TrackingBloc>().add(
        ConfirmDeliveryRequested(
          bidId: widget.bidId,
          code: code,
          photo: photo,
          scanMethod: widget.scanMethod,
          gpsLat: widget.gpsLat,
          gpsLon: widget.gpsLon,
          gpsLabel: widget.gpsLabel,
        ),
      );
    } else {
      context.read<TrackingBloc>().add(
        QrScanSubmitRequested(
          bidId: widget.bidId,
          eventType: widget.etape,
          photo: photo,
          gpsLat: widget.gpsLat,
          gpsLon: widget.gpsLon,
          gpsLabel: widget.gpsLabel,
          scanMethod: widget.scanMethod,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final etapeIcons = _etapeIcons[widget.etape];
    final etapeLabel = trackingStepLabel(l, widget.etape);
    final locationLabel = _displayLocationLabel(l);

    return BlocConsumer<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is QrScanSuccess) {
          if (state.photoDropped) warnTrackingPhotoDropped(context);
          _showSuccess(context, state.event.stepLabel(l));
        } else if (state is QrScanQueued) {
          _showQueued(context);
        } else if (state is DeliveryConfirmSuccess) {
          if (state.photoDropped) warnTrackingPhotoDropped(context);
          _navigateToDeliverySuccess(
            context,
            state.event.stepLabel(l),
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
            actions: const [DonyFeedbackButton()],
            leading: const DonyAppBarBackButton(),
            backgroundColor: cs.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            title: Text(l.scanConfirmReadingLabel, style: tt.headlineLarge),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: cs.outline),
            ),
          ),
          // Le bouton principal est épinglé hors du défilement : avec le clavier
          // numérique ouvert, il restait sous la fiche du colis, hors d'écran
          // (FLUTTER-BN, BF). Le Scaffold ne remonte pas cette barre avec le
          // clavier : on la décale de sa hauteur.
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.sm,
                DonySpacing.lg,
                DonySpacing.base + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bouton principal, verrouillé avant le départ du trajet
                  // pour une remise (ARRIVEE).
                  DeliveryDepartureGate(
                    window: _isArrivee ? widget.deliveryWindow : null,
                    builder: (context, lockedHint) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DonyButton(
                          key: const Key('scan-confirm-submit'),
                          label: _isArrivee
                              ? l.scanConfirmDeliveryButton
                              : l.scanValidateReadingButton,
                          iconAsset: _isArrivee ? 'badge-check' : 'check',
                          onPressed: isSubmitting || lockedHint != null
                              ? null
                              : () => _submit(context),
                          isLoading: isSubmitting,
                        ),
                        if (lockedHint != null) ...[
                          const SizedBox(height: DonySpacing.xs),
                          DeliveryLockedHint(lockedHint),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: DonySpacing.sm),

                  // Reprendre photo
                  if (widget.photoPath != null)
                    TextButton.icon(
                      onPressed: isSubmitting ? null : () => context.pop(),
                      icon: DonyIcon(
                        'refresh-cw',
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      label: Text(l.scanRetakePhotoButton),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                      ),
                    ),

                  // Message d'erreur
                  if (state is QrScanError ||
                      state is DeliveryConfirmError) ...[
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
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Code bloqué ou expiré (FLUTTER-G2) : seul l'expéditeur
                  // peut en générer un nouveau, le voyageur le lui demande
                  // d'ici au lieu de quitter l'écran pour le joindre.
                  if (state is DeliveryConfirmError &&
                      needsPickupCodeRequest(state.error.code)) ...[
                    const SizedBox(height: DonySpacing.sm),
                    PickupCodeRequestPanel(
                      key: const Key('scan-confirm-code-request'),
                      bidId: widget.bidId,
                      source: 'scan_confirm',
                    ),
                  ],
                ],
              ),
            ),
          ),
          body: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chip étape
                if (etapeIcons != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: switch (etapeIcons.$2) {
                        'plane-takeoff' => const DonyEmoji.planeTakeoff(
                          size: 14,
                        ),
                        'plane-landing' => const DonyEmoji.planeLanding(
                          size: 14,
                        ),
                        _ => DonyIcon(
                          etapeIcons.$1!,
                          size: 14,
                          color: cs.primary,
                        ),
                      },
                      label: Text(l.scanStepRecorded(widget.etape)),
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
                                errorBuilder: (_, _, _) => _PhotoPlaceholder(),
                              )
                            : _PhotoPlaceholder(),
                      ),
                      // Lignes méta
                      Padding(
                        padding: const EdgeInsets.all(DonySpacing.base),
                        child: Column(
                          children: [
                            _MetaRow(
                              label: l.scanConfirmParcelLabel,
                              value: widget.packageLabel,
                            ),
                            const Divider(height: DonySpacing.base),
                            _MetaRow(
                              label: l.scanConfirmStepLabel,
                              value: etapeLabel,
                            ),
                            if (locationLabel != null) ...[
                              const SizedBox(height: DonySpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DonySpacing.sm,
                                  vertical: DonySpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(
                                    DonyRadius.sm,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DonyIcon(
                                      'map-pin',
                                      color: cs.primary,
                                      size: 13,
                                    ),
                                    const SizedBox(width: DonySpacing.xs),
                                    // Adresse du géocodage inverse, de longueur
                                    // imprévisible : sans Flexible elle débordait
                                    // la pastille en 360 dp (Sentry FLUTTER-3W).
                                    Flexible(
                                      child: Text(
                                        locationLabel,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.labelSmall?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                        DonyIcon('info', color: cs.primary, size: 15),
                        const SizedBox(width: DonySpacing.sm),
                        Expanded(
                          child: Text(
                            l.scanConfirmConfirmationCodeHint,
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
                    // Chiffres seuls : un code collé avec une espace (« 123 456 »)
                    // était tronqué à 6 caractères puis refusé par le serveur.
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
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
              ],
            ),
          ),
        );
      },
    );
  }

  String? _displayLocationLabel(AppLocalizations l) {
    final label = widget.gpsLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (widget.gpsLat != null && widget.gpsLon != null) {
      return l.scanGpsLocationSaved;
    }
    return null;
  }

  void _showSuccess(BuildContext context, String label) {
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
            const DonyMascotteAnimated(
              type: DonyMascotteType.confiant,
              size: DonyMascotteSize.lg,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              l.scanRecordedTitle,
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
              onPressed: () {
                ctx.pop();
                leaveScanFlow(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
              child: Text(l.commonDone),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDeliverySuccess(
    BuildContext context,
    String label, {
    required String finalBidId,
  }) {
    final l = context.l10n;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DonySuccessScreen(
          mascotteType: DonyMascotteType.succes,
          title: l.scanParcelDeliveredTitle,
          subtitle: label,
          ctaLabel: l.scanTerminateButton,
          ctaVariant: DonyButtonVariant.success,
          onCta: () async {
            await RatingBottomSheet.show(
              context,
              bidId: finalBidId,
              isTravelerRating: true,
            );
            if (!context.mounted) return;
            context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
            leaveScanFlow(context);
          },
          analyticsContext: 'delivery_confirmed',
        ),
      ),
    );
  }

  void _showQueued(BuildContext context) {
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
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              l.scanConfirmQueuedNoConnectionBody,
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
                leaveScanFlow(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.warning,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
              child: Text(l.scanUnderstoodButton),
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
        child: DonyIcon('camera', color: cs.onSurfaceVariant, size: 32),
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
      children: [
        Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(width: DonySpacing.sm),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Fin d'un scan : retour à l'écran qui l'a lancé (détail du colis, mode
/// Valider d'un trajet), en refermant les étapes du flux. Avant, un
/// `go('/tracking')` vidait la pile et le voyageur ne pouvait plus revenir
/// au colis (FLUTTER-9N). Lancé depuis l'onglet Suivi, ou ouvert sans
/// rien dessous (lien), on retombe sur l'onglet comme avant.
@visibleForTesting
void leaveScanFlow(BuildContext context) {
  final router = GoRouter.of(context);
  var landed = false;
  Navigator.of(context, rootNavigator: true).popUntil((route) {
    final name = route.settings.name;
    // Sans nom : feuilles, dialogues et écran de succès du flux.
    final inFlow = name == null || name.startsWith('/tracking/scan');
    if (!inFlow) landed = true;
    return !inFlow || route.isFirst;
  });
  if (!landed) router.go('/tracking');
}
