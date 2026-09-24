import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
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
    final l = context.l10n;
    return DonyBottomSheet.show(
      context,
      title: l.scanOfflineCount(items.length),
      subtitle: l.scanOfflineSyncingSubtitle,
      wrapper: (child) => BlocProvider.value(value: trackingBloc, child: child),
      stickyBottom: DonyButton(
        label: l.scanSyncButton,
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
    final l = context.l10n;

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
                        Text(
                          item.donNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall,
                        ),
                        const SizedBox(height: DonySpacing.xxs),
                        Text(
                          item.eventType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Flexible(
                    child: Text(
                      scanRelativeTime(
                        l,
                        DateTime.now().difference(item.timestamp),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
      child: DonyIcon('qr-code', size: 18, color: cs.onPrimaryContainer),
    );
  }
}
