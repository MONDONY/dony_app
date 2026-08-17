import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class _StatusOption {
  const _StatusOption(this.code, this.label);
  final String code;
  final String label;
}

const _groups = <String, List<_StatusOption>>{
  'En cours': [
    _StatusOption('ACCEPTED', 'Confirmé'),
    _StatusOption('HANDED_OVER', 'En route'),
    _StatusOption('IN_TRANSIT', 'En transit'),
    _StatusOption('ARRIVED', 'Arrivé'),
  ],
  'En attente': [
    _StatusOption('PENDING', 'En attente'),
    _StatusOption('AWAITING_PAYMENT', 'À payer'),
    _StatusOption('PAYMENT_ESCROWED', 'Payé'),
  ],
  'Terminés': [_StatusOption('COMPLETED', 'Livré')],
  'Clôturés': [
    _StatusOption('CANCELLED', 'Annulé'),
    _StatusOption('REJECTED', 'Refusé'),
    _StatusOption('PARCEL_REFUSED', 'Colis refusé'),
    _StatusOption('NO_SHOW', 'Absent'),
    _StatusOption('EXPIRED', 'Expiré'),
  ],
};

class ShipmentStatusFilterSheet {
  /// Retourne le Set de statuts choisi, ou null si annulé.
  static Future<Set<String>?> show(BuildContext context, Set<String> initial) {
    final selected = ValueNotifier<Set<String>>({...initial});
    return DonyBottomSheet.show<Set<String>>(
      context,
      title: 'Filtrer par statut',
      stickyBottom: ValueListenableBuilder<Set<String>>(
        valueListenable: selected,
        builder: (context, value, _) => DonyButton(
          label: value.isEmpty ? 'Appliquer' : 'Appliquer (${value.length})',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(value),
        ),
      ),
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: selected,
        builder: (context, value, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in _groups.entries) ...[
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
