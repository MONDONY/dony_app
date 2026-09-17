import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:flutter/material.dart';

abstract final class RequestOwnerMenuSheet {
  static Future<RequestMenuAction?> show(
    BuildContext context, {
    required List<RequestMenuAction> items,
  }) {
    return DonyBottomSheet.show<RequestMenuAction>(
      context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              _MenuRow(
                item: item,
                onTap: () => Navigator.of(sheetContext).pop(item),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});
  final RequestMenuAction item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, label, consequence, danger) = switch (item) {
      RequestMenuAction.unpublish => (
        'eye-off',
        'Dépublier',
        'Redevient un brouillon, invisible des voyageurs',
        false,
      ),
      RequestMenuAction.duplicate => (
        'copy',
        'Dupliquer la demande',
        'Même colis, nouvelles dates ou nouveau trajet',
        false,
      ),
      RequestMenuAction.cancel => (
        'circle-x',
        'Annuler la demande',
        'Irréversible',
        true,
      ),
    };
    final color = danger ? cs.error : cs.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.sm,
        ),
        child: Row(
          children: [
            DonyIcon(icon, size: 20, color: color),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    consequence,
                    style: TextStyle(
                      fontSize: 12,
                      color: danger
                          ? cs.error.withValues(alpha: 0.8)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
