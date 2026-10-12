import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineScanQueueScreen extends StatelessWidget {
  const OfflineScanQueueScreen({super.key});

  static String _relativeTime(AppLocalizations l, String isoTimestamp) {
    final ts = DateTime.tryParse(isoTimestamp);
    if (ts == null) {
      return '';
    }
    final diff = DateTime.now().toUtc().difference(ts);
    return scanRelativeTime(l, diff);
  }

  static String _eventLabel(AppLocalizations l, String eventType) {
    return switch (eventType.toUpperCase()) {
      'PICKUP' => l.scanOfflineEventPickupLabel,
      'IN_TRANSIT' => l.scanOfflineEventTransitLabel,
      'DELIVERED' => l.scanOfflineEventDeliveredLabel,
      _ => l.scanOfflineEventDefaultLabel,
    };
  }

  static String _eventDescription(AppLocalizations l, String eventType) {
    return switch (eventType.toUpperCase()) {
      'PICKUP' => l.scanOfflineDescPickup,
      'IN_TRANSIT' => l.scanOfflineDescTransit,
      'DELIVERED' => l.scanOfflineDescDelivered,
      _ => l.scanOfflineDescDefault,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final queue = getIt<HiveService>().offlineQueue;

    // Rebâti à chaque envoi : une étape partie disparaît de la liste.
    return ValueListenableBuilder(
      valueListenable: queue.listenable(),
      builder: (context, _, _) {
        final entries = queue.values
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
        return _buildScaffold(context, cs, tt, l, entries);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    AppLocalizations l,
    List<Map<String, dynamic>> entries,
  ) {
    final count = entries.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(
        title: l.scanOfflineQueueTitle,
        // La pastille « Hors-ligne » était dans les actions : avec le retour
        // et le scarabée, elle réduisait le titre à « Lectures ho… » à 360 dp
        // (Sentry FLUTTER-KN, Redmi). Elle vit maintenant en tête du contenu.
      ),
      body: Builder(
        builder: (context) {
          final h = DonyLayout.hPadding(context);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              h,
              DonySpacing.xl,
              h,
              DonySpacing.huge,
            ),
            child: DonyLayout.constrained(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _OfflineBadge(),
                  const SizedBox(height: DonySpacing.md),
                  _AlertBanner(count: count),
                  const SizedBox(height: DonySpacing.xl),

                  Text(
                    l.scanOfflineQueueSectionTitle(count),
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.base),

                  if (entries.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(DonySpacing.xxl),
                        child: Text(
                          l.scanOfflineQueueEmpty,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    ...entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                        child: _QueueItemCard(
                          bidId: entry['bidId'] as String? ?? '',
                          eventType: entry['eventType'] as String? ?? '',
                          timestamp: entry['offlineTimestamp'] as String? ?? '',
                        ),
                      ),
                    ),

                  // L'envoi repart seul (retour du réseau, retour dans l'app,
                  // nouvel essai espacé) ; ce bouton évite d'attendre quand
                  // le réseau est visiblement revenu (FLUTTER-KZ).
                  if (entries.isNotEmpty) ...[
                    const SizedBox(height: DonySpacing.base),
                    DonyButton(
                      key: const Key('offline-queue-retry'),
                      label: l.scanOfflineQueueRetryNow,
                      variant: DonyButtonVariant.secondary,
                      onPressed: () =>
                          unawaited(getIt<OfflineSyncService>().syncAll()),
                    ),
                  ],
                  const SizedBox(height: DonySpacing.xxl),
                  Center(
                    child: Text(
                      l.scanOfflineFooterHint,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Alert banner ─────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.secondary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('shield', color: cs.secondary, size: DonySpacing.iconSm),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.scanQueueSafeTitle,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.scanQueueSafe(count),
                  style: tt.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Queue item card ───────────────────────────────────────────────────────────

class _QueueItemCard extends StatelessWidget {
  const _QueueItemCard({
    required this.bidId,
    required this.eventType,
    required this.timestamp,
  });

  final String bidId;
  final String eventType;
  final String timestamp;

  String get _shortCode {
    if (bidId.length >= 4) {
      return '#${bidId.substring(0, 4).toUpperCase()}';
    }
    return '#${bidId.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final label = OfflineScanQueueScreen._eventLabel(l, eventType);
    final description = OfflineScanQueueScreen._eventDescription(l, eventType);
    final relTime = OfflineScanQueueScreen._relativeTime(l, timestamp);

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          DonyIcon(
            'qr-code',
            size: DonySpacing.iconSm,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l.scanOfflineParcelCode(_shortCode),
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    _EventChip(label: label),
                  ],
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  '$description · $relTime',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          DonyIcon('clock', size: 16, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ── Event chip ────────────────────────────────────────────────────────────────

class _EventChip extends StatelessWidget {
  const _EventChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.xs,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// Pastille « Hors-ligne », en tête du contenu plutôt que dans l'AppBar.
class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const Key('offline-queue-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.secondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('wifi-off', size: 12, color: cs.secondary),
          const SizedBox(width: DonySpacing.xs),
          Text(
            context.l10n.scanOfflineBadge,
            style: tt.labelMedium?.copyWith(color: cs.secondary),
          ),
        ],
      ),
    );
  }
}
