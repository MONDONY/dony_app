import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:dony/features/tracking/bloc/suivi_cubit.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/features/tracking/presentation/widgets/parcel_not_linked_notice.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Libellé court d'un colis : destinataire, sinon numéro de suivi, sinon
/// début de l'identifiant.
String suiviParcelLabel(BidModel bid) =>
    bid.recipientName ??
    bid.trackingNumber ??
    bid.id.substring(0, bid.id.length < 8 ? bid.id.length : 8).toUpperCase();

/// « Paris → Dakar ».
String suiviCorridor(AnnouncementModel trip) =>
    '${trip.departureCity} → ${trip.arrivalCity}';

/// « sam. 26 sept. » dans la langue de l'app.
String suiviShortDate(AppLocalizations l, DateTime date) =>
    DateFormat.MMMEd(l.localeName).format(date);

/// Contenu de la feuille du mode « Valider une étape » : trajet affiché,
/// colis et leur prochaine étape, derniers scans.
///
/// Feuille repliée : « QR illisible ? Saisir le numéro » sous les colis.
/// Dépliée : l'étape automatique (et « Forcer une étape ») puis le champ
/// numéro, sous le trajet.
class SuiviValidateContent extends StatelessWidget {
  const SuiviValidateContent({
    super.key,
    required this.hub,
    required this.expanded,
    required this.numberFocus,
    required this.onChangeTrip,
    required this.onValidateParcel,
    required this.onEnterNumber,
    required this.onSubmitNumber,
    required this.onForceStep,
  });

  final ScanHubLoaded hub;

  /// Feuille tirée en haut.
  final ValueListenable<bool> expanded;

  /// Focus du champ numéro, donné par « QR illisible ? ».
  final FocusNode numberFocus;
  final VoidCallback onChangeTrip;

  /// Action d'une ligne colis : valide son [step] (photo, puis bandeau
  /// « Annuler » ou code du destinataire pour l'arrivée).
  final void Function(BidModel bid, String step) onValidateParcel;

  /// « QR illisible ? Saisir le numéro » : déplie la feuille sur le champ.
  final VoidCallback onEnterNumber;

  /// Numéro saisi puis « Valider ».
  final ValueChanged<String> onSubmitNumber;

  /// « Forcer une étape ».
  final VoidCallback onForceStep;

  @override
  Widget build(BuildContext context) {
    final bids = hub.selectedTripBids;
    return ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (context, isExpanded, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SuiviPendingScansBanner(bidIds: {for (final b in bids) b.id}),
          _TripRow(hub: hub, onChangeTrip: onChangeTrip),
          if (isExpanded) ...[
            const SizedBox(height: DonySpacing.sm),
            _StepModeRow(onForceStep: onForceStep),
            const SizedBox(height: DonySpacing.sm),
            _ValidateNumberField(
              focusNode: numberFocus,
              onSubmit: onSubmitNumber,
            ),
          ],
          const SizedBox(height: DonySpacing.base),
          _ParcelList(
            bids: bids,
            history: hub.scanHistory,
            onValidateParcel: onValidateParcel,
          ),
          if (!isExpanded) ...[
            const SizedBox(height: DonySpacing.base),
            _EnterNumberButton(onTap: onEnterNumber),
          ],
          const SizedBox(height: DonySpacing.xl),
          _RecentScans(history: hub.scanHistory),
        ],
      ),
    );
  }
}

/// « Étape : automatique », repliable sur son explication, et « Forcer une
/// étape » pour rattraper un oubli. Étape forcée : « Étape : départ » (ou
/// transit, arrivée) et « Automatique » pour revenir.
class _StepModeRow extends StatelessWidget {
  const _StepModeRow({required this.onForceStep});

  final VoidCallback onForceStep;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return BlocBuilder<SuiviCubit, SuiviState>(
      buildWhen: (a, b) => a.forcedStep != b.forcedStep,
      builder: (context, state) {
        final forcedStep = state.forcedStep;
        final forced = forcedStep != null;
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('suivi-step-mode'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: DonySpacing.md),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            minTileHeight: 48,
            title: Text.rich(
              TextSpan(
                text: l.suiviStepModeLabel,
                children: [
                  TextSpan(
                    text: forced
                        ? l.suiviStepModeForced(forcedStep)
                        : l.suiviStepModeAuto,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: forced ? DonyColors.accent : null,
                    ),
                  ),
                ],
              ),
              style: tt.bodyLarge,
            ),
            trailing: TextButton(
              key: Key(forced ? 'suivi-step-auto' : 'suivi-force-step'),
              onPressed: forced
                  ? context.read<SuiviCubit>().clearForcedStep
                  : onForceStep,
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                forced ? l.suiviStepModeBackToAuto : l.suiviForceStep,
                style: tt.labelLarge,
              ),
            ),
            children: [
              Text(
                forced
                    ? l.suiviStepModeForcedHelp(forcedStep)
                    : l.suiviStepModeHelp,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Champ « Numéro du colis » de la feuille dépliée. Le contrôleur vit ici,
/// jamais dans l'écran.
class _ValidateNumberField extends StatefulWidget {
  const _ValidateNumberField({required this.focusNode, required this.onSubmit});

  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;

  @override
  State<_ValidateNumberField> createState() => _ValidateNumberFieldState();
}

class _ValidateNumberFieldState extends State<_ValidateNumberField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    widget.focusNode.unfocus();
    widget.onSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(DonyRadius.lg),
      borderSide: BorderSide(color: cs.outline),
    );

    return BlocBuilder<SuiviCubit, SuiviState>(
      buildWhen: (a, b) =>
          a.numberStatus != b.numberStatus || a.numberError != b.numberError,
      builder: (context, state) {
        final loading = state.numberStatus == SuiviLoadStatus.loading;
        final error = state.numberStatus == SuiviLoadStatus.error
            ? state.numberError
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('suivi-validate-number-field'),
                    controller: _controller,
                    focusNode: widget.focusNode,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    style: tt.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: _tabular,
                    ),
                    decoration: InputDecoration(
                      hintText: l.suiviNumberHint,
                      filled: true,
                      fillColor: cs.surface,
                      border: border,
                      enabledBorder: border,
                      focusedBorder: border.copyWith(
                        borderSide: BorderSide(color: cs.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('suivi-validate-number-submit'),
                    onPressed: loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      // Largeur minimale bornée : celle du thème est infinie.
                      minimumSize: const Size(64, 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.lg,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                      ),
                    ),
                    child: loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : Text(l.suiviNumberSubmit, style: tt.labelLarge),
                  ),
                ),
              ],
            ),
            if (error is ForbiddenException) ...[
              const SizedBox(height: DonySpacing.md),
              const ParcelNotLinkedNotice(),
            ] else if (error != null) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                error is NotFoundException
                    ? l.suiviNumberNotFound
                    : ErrorPresenter.resolve(error, l10n: l).message,
                key: const Key('suivi-validate-number-error'),
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.hub, required this.onChangeTrip});

  final ScanHubLoaded hub;
  final VoidCallback onChangeTrip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final trip = hub.selectedTrip;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suiviCorridor(trip),
                key: const Key('suivi-selected-trip'),
                style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                l.suiviTripSummary(
                  suiviShortDate(l, trip.departureDate),
                  hub.selectedTripBids.length,
                ),
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
        ),
        if (hub.trips.length > 1) ...[
          const SizedBox(width: DonySpacing.sm),
          OutlinedButton.icon(
            key: const Key('suivi-change-trip'),
            onPressed: onChangeTrip,
            icon: Icon(DonyIcons.swapVertical, size: 16, color: cs.onSurface),
            label: Text(l.suiviChangeTrip),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurface,
              backgroundColor: cs.surface,
              side: BorderSide(color: cs.outline),
              minimumSize: const Size(0, 44),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ],
    );
  }
}

class _ParcelList extends StatelessWidget {
  const _ParcelList({
    required this.bids,
    required this.history,
    required this.onValidateParcel,
  });

  final List<BidModel> bids;
  final List<TripScanHistoryEntryModel> history;
  final void Function(BidModel bid, String step) onValidateParcel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: l.suiviParcelsTitle,
            children: [
              TextSpan(
                text: '  ${bids.length}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.sm),
        if (bids.isEmpty)
          Text(
            l.scanNoColisConfirmed,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < bids.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: cs.outline.withValues(alpha: .6)),
                  _ParcelRow(
                    bid: bids[i],
                    lastScan: _lastScanOf(bids[i]),
                    onValidate: onValidateParcel,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Dernier scan connu du colis. L'historique ne porte pas l'identifiant du
  /// bid : on rapproche par numéro de suivi.
  TripScanHistoryEntryModel? _lastScanOf(BidModel bid) {
    final number = bid.trackingNumber;
    if (number == null) return null;
    TripScanHistoryEntryModel? latest;
    for (final entry in history) {
      if (entry.donNumber != number) continue;
      if (latest == null || entry.scannedAt.isAfter(latest.scannedAt)) {
        latest = entry;
      }
    }
    return latest;
  }
}

class _ParcelRow extends StatelessWidget {
  const _ParcelRow({
    required this.bid,
    required this.lastScan,
    required this.onValidate,
  });

  final BidModel bid;
  final TripScanHistoryEntryModel? lastScan;
  final void Function(BidModel bid, String step) onValidate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final label = suiviParcelLabel(bid);
    final next = nextRequiredStep(bid);
    final progress = colisStepProgress(bid);
    final scan = lastScan;

    final String? subtitle;
    if (scan != null) {
      subtitle = l.suiviLastStepAt(
        scan.eventType,
        DateFormat.Hm(l.localeName).format(scan.scannedAt.toLocal()),
      );
    } else if (!progress.depart) {
      subtitle = l.suiviNotHandedOver;
    } else {
      subtitle = null;
    }

    return InkWell(
      key: Key('suivi-parcel-${bid.id}'),
      onTap: () => context.push('/bids/${bid.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 18,
                backgroundColor: cs.surfaceWarm,
                child: Text(
                  label.characters.first.toUpperCase(),
                  style: tt.labelLarge?.copyWith(color: DonyColors.terra800),
                ),
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  _StepSegments(progress: progress),
                  if (subtitle != null) ...[
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            // Flexible : à 200 % de texte, le libellé passe à la ligne au
            // lieu de pousser la ligne hors de l'écran.
            Flexible(
              flex: 2,
              child: next != null
                  ? TextButton(
                      key: Key('suivi-validate-${bid.id}'),
                      onPressed: () => onValidate(bid, next),
                      style: TextButton.styleFrom(
                        backgroundColor: cs.primary.withValues(alpha: 0.10),
                        foregroundColor: cs.primary,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DonyRadius.md),
                        ),
                      ),
                      child: Text(
                        l.suiviValidateStep(next),
                        textAlign: TextAlign.center,
                        style: tt.labelLarge,
                      ),
                    )
                  : Text(
                      l.suiviAllValidated,
                      textAlign: TextAlign.end,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trois segments Départ / Transit / Arrivée.
class _StepSegments extends StatelessWidget {
  const _StepSegments({required this.progress});

  final ({bool depart, bool transit, bool arrivee}) progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = [progress.depart, progress.transit, progress.arrivee];
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 90),
        child: Row(
          children: [
            for (var i = 0; i < done.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  key: Key(done[i] ? 'step_dot_done' : 'step_dot_todo'),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done[i] ? cs.primary : cs.outline,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnterNumberButton extends StatelessWidget {
  const _EnterNumberButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      key: const Key('suivi-enter-number'),
      onPressed: onTap,
      icon: DonyIcon('square-pen', size: 17, color: cs.onSurface),
      label: Text(context.l10n.suiviEnterNumber, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: cs.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.lg),
        ),
      ),
    );
  }
}

class _RecentScans extends StatelessWidget {
  const _RecentScans({required this.history});

  final List<TripScanHistoryEntryModel> history;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final entries = [...history]
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.suiviRecentScans,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.sm),
        if (entries.isEmpty)
          Text(
            l.scanNoHistoryYet,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          for (final entry in entries.take(10))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      DateFormat.Hm(
                        l.localeName,
                      ).format(entry.scannedAt.toLocal()),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Text(
                      entry.recipientName ?? entry.donNumber ?? '-',
                      style: tt.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Text(
                    recentScanStepLabel(l, entry),
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Scans enregistrés hors ligne pour ces colis, pas encore envoyés.
/// Masqué quand la file est vide pour eux ; se met à jour avec la file.
class SuiviPendingScansBanner extends StatelessWidget {
  const SuiviPendingScansBanner({super.key, required this.bidIds});

  final Set<String> bidIds;

  @override
  Widget build(BuildContext context) {
    final sync = getIt<OfflineSyncService>();
    return ListenableBuilder(
      listenable: sync.queueChanges,
      builder: (context, _) {
        final count = sync.pendingCountFor(bidIds);
        if (count == 0) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.base),
          child: Material(
            color: cs.surfaceWarm,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            child: InkWell(
              key: const Key('suivi-pending-scans'),
              borderRadius: BorderRadius.circular(DonyRadius.lg),
              onTap: () => context.push('/tracking/offline-queue'),
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.md),
                child: Row(
                  children: [
                    DonyIcon('wifi-off', size: 18, color: cs.onSurface),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Text(
                        context.l10n.suiviPendingScans(count),
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface,
                          fontFeatures: _tabular,
                        ),
                      ),
                    ),
                    DonyIcon(
                      'chevron-right',
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Feuille « Choisir un trajet » : trajets en cours puis à venir.
class SuiviTripPicker extends StatelessWidget {
  const SuiviTripPicker({super.key, required this.hub, required this.onSelect});

  final ScanHubLoaded hub;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Statuts back comparés, jamais affichés (i18n-ignore).
    final inProgress = hub.trips.where((t) => t.status == 'IN_PROGRESS');
    final upcoming = hub.trips.where((t) => t.status != 'IN_PROGRESS');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inProgress.isNotEmpty)
          _TripGroup(
            title: l.suiviTripsInProgress,
            trips: inProgress.toList(),
            hub: hub,
            onSelect: onSelect,
          ),
        if (upcoming.isNotEmpty)
          _TripGroup(
            title: l.suiviTripsUpcoming,
            trips: upcoming.toList(),
            hub: hub,
            onSelect: onSelect,
          ),
      ],
    );
  }
}

class _TripGroup extends StatelessWidget {
  const _TripGroup({
    required this.title,
    required this.trips,
    required this.hub,
    required this.onSelect,
  });

  final String title;
  final List<AnnouncementModel> trips;
  final ScanHubLoaded hub;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          for (final trip in trips)
            Builder(
              builder: (context) {
                final selected = trip.id == hub.selectedTripId;
                final bids = hub.confirmedBidsOf(trip.id);
                final toValidate = bids
                    .where((b) => nextRequiredStep(b) != null)
                    .length;
                final summary = l.suiviTripSummary(
                  suiviShortDate(l, trip.departureDate),
                  bids.length,
                );
                return Semantics(
                  selected: selected,
                  button: true,
                  child: InkWell(
                    key: Key('trip_option_${trip.id}'),
                    borderRadius: BorderRadius.circular(DonyRadius.lg),
                    onTap: () {
                      onSelect(trip.id);
                      Navigator.of(context).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: DonySpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suiviCorridor(trip),
                                  style: tt.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  toValidate > 0
                                      ? '$summary · ${l.suiviToValidateCount(toValidate)}'
                                      : summary,
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontFeatures: _tabular,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: DonySpacing.md),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected ? cs.primary : null,
                              border: selected
                                  ? null
                                  : Border.all(color: cs.outline, width: 2),
                            ),
                            child: selected
                                ? DonyIcon(
                                    'check',
                                    size: 14,
                                    color: cs.onPrimary,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
