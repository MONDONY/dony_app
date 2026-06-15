import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OfflineScanItem {
  const OfflineScanItem({
    required this.donNumber,
    required this.eventType,
    required this.timestamp,
  });

  final String donNumber;
  final String eventType;
  final DateTime timestamp;
}

class OfflineQueueBottomSheet extends StatelessWidget {
  const OfflineQueueBottomSheet({super.key, required this.items});

  final List<OfflineScanItem> items;

  static Future<void> show(
    BuildContext context, {
    required List<OfflineScanItem> items,
  }) {
    final trackingBloc = context.read<TrackingBloc>();
    return DonyBottomSheet.show(
      context,
      title: '${items.length} scan${items.length > 1 ? 's' : ''} hors-ligne',
      subtitle: 'En attente de synchronisation',
      wrapper: (child) => BlocProvider.value(value: trackingBloc, child: child),
      stickyBottom: DonyButton(
        label: 'Synchroniser',
        iconAsset: 'refresh-cw',
        onPressed: () {
          trackingBloc.add(OfflineSyncRequested());
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
      child: OfflineQueueBottomSheet(items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(DonySpacing.base),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                children: [
                  _EventIconBox(eventType: item.eventType, cs: cs),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.donNumber, style: tt.titleSmall),
                        const SizedBox(height: DonySpacing.xxs),
                        Text(
                          item.eventType,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _relativeTime(item.timestamp),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _relativeTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'il y a < 1 min';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    return 'il y a ${diff.inHours}h';
  }
}

class _EventIconBox extends StatelessWidget {
  const _EventIconBox({required this.eventType, required this.cs});

  final String eventType;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: DonyIcon(
        'qr-code',
        size: 18,
        color: cs.onPrimaryContainer,
      ),
    );
  }
}
