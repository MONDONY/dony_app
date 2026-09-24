import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

class _StatusOption {
  const _StatusOption(this.code, this.label);
  final String code;
  final String label;
}

/// Groupes de statuts affichés dans le sheet, calculés à partir des
/// traductions courantes (les libellés de groupe et d'option dépendent de la
/// langue, donc jamais de `const`/top-level figé).
Map<String, List<_StatusOption>> _groups(AppLocalizations l) => {
  l.shipmentGroupInProgress: [
    _StatusOption('ACCEPTED', l.shipmentStatusToHandOverOption),
    _StatusOption('HANDED_OVER', l.shipmentStatusHandedOverOption),
    _StatusOption('IN_TRANSIT', l.shipmentStatusInTransitOption),
    _StatusOption('ARRIVED', l.shipmentStatusArrivedOption),
  ],
  l.shipmentGroupWaiting: [
    _StatusOption('PENDING', l.shipmentGroupWaiting),
    _StatusOption('AWAITING_PAYMENT', l.shipmentStatusAwaitingPaymentOption),
    _StatusOption('PAYMENT_ESCROWED', l.shipmentStatusPaidOption),
  ],
  l.shipmentGroupDelivered: [
    _StatusOption('COMPLETED', l.shipmentStatusDeliveredOption),
  ],
  l.shipmentGroupNotCompleted: [
    _StatusOption('CANCELLED', l.shipmentStatusCancelledOption),
    _StatusOption('REJECTED', l.shipmentStatusRejectedOption),
    _StatusOption('PARCEL_REFUSED', l.shipmentStatusParcelRefusedOption),
    _StatusOption('NO_SHOW', l.shipmentStatusNoShowOption),
    _StatusOption('EXPIRED', l.shipmentStatusExpiredOption),
  ],
};

class ShipmentStatusFilterSheet {
  /// Retourne le Set de statuts choisi, ou null si annulé.
  static Future<Set<String>?> show(BuildContext context, Set<String> initial) {
    final selected = ValueNotifier<Set<String>>({...initial});
    final l = context.l10n;
    final groups = _groups(l);
    return DonyBottomSheet.show<Set<String>>(
      context,
      title: l.shipmentStatusFilterTitle,
      stickyBottom: ValueListenableBuilder<Set<String>>(
        valueListenable: selected,
        builder: (context, value, _) => DonyButton(
          label: value.isEmpty
              ? l.commonApply
              : l.shipmentStatusFilterApplyWithCount(value.length),
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(value),
        ),
      ),
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: selected,
        builder: (context, value, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  DonySpacing.sm,
                  0,
                  DonySpacing.xxs,
                ),
                child: Text(
                  entry.key.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              for (final opt in entry.value)
                DonyCheckbox(
                  label: opt.label,
                  value: value.contains(opt.code),
                  onChanged: (checked) {
                    final next = {...value};
                    if (checked == true) {
                      next.add(opt.code);
                    } else {
                      next.remove(opt.code);
                    }
                    selected.value = next;
                  },
                ),
            ],
          ],
        ),
      ),
    ).whenComplete(selected.dispose);
  }
}
