import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

class OfflineScanQueueScreen extends StatelessWidget {
  const OfflineScanQueueScreen({super.key});

  static String _relativeTime(String isoTimestamp) {
    final ts = DateTime.tryParse(isoTimestamp);
    if (ts == null) {
      return '';
    }
    final diff = DateTime.now().toUtc().difference(ts);
    if (diff.inMinutes < 1) {
      return 'il y a < 1 min';
    }
    if (diff.inMinutes < 60) {
      return 'il y a ${diff.inMinutes} min';
    }
    return 'il y a ${diff.inHours}h';
  }

  static String _eventLabel(String eventType) {
    return switch (eventType.toUpperCase()) {
      'PICKUP' => 'collecte',
      'IN_TRANSIT' => 'transit',
      'DELIVERED' => 'livré',
      _ => 'file',
    };
  }

  static String _eventDescription(String eventType) {
    return switch (eventType.toUpperCase()) {
      'PICKUP' => 'Collecte enregistrée',
      'IN_TRANSIT' => 'En transit sauvegardé',
      'DELIVERED' => 'Livraison sauvegardée',
      _ => 'Scan sauvegardé',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final queue = getIt<HiveService>().offlineQueue;
    final entries = queue.values
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
    final count = entries.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(
        title: 'Scans hors-ligne',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DonySpacing.base),
            child: Center(
              child: Container(
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
                    DonyIcon(
                      'wifi-off',
                      size: 12,
                      color: cs.secondary,
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      'Hors-ligne',
                      style: tt.labelMedium?.copyWith(color: cs.secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(h, DonySpacing.xl, h, DonySpacing.huge),
          child: DonyLayout.constrained(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _AlertBanner(count: count),
            const SizedBox(height: DonySpacing.xl),

            Text(
              "FILE D'ATTENTE ($count)",
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
                    'Aucun scan en attente.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                    child: _QueueItemCard(
                      bidId: entry['bidId'] as String? ?? '',
                      eventType: entry['eventType'] as String? ?? '',
                      timestamp: entry['offlineTimestamp'] as String? ?? '',
                    ),
                  )),

            const SizedBox(height: DonySpacing.xxl),
            Center(
              child: Text(
                'Continuez à scanner même sans réseau.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ],
            ),
          ),
        );
      }),
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
          DonyIcon(
            'shield',
            color: cs.secondary,
            size: DonySpacing.iconSm,
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vos scans sont en sécurité',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  '$count scans en attente. On les enverra dès que vous récupérez du réseau.',
                  style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    final label = OfflineScanQueueScreen._eventLabel(eventType);
    final description = OfflineScanQueueScreen._eventDescription(eventType);
    final relTime = OfflineScanQueueScreen._relativeTime(timestamp);

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
                      'colis $_shortCode',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
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
          DonyIcon(
            'clock',
            size: 16,
            color: cs.onSurfaceVariant,
          ),
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
