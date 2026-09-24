import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

class ShipmentPeriodResult {
  const ShipmentPeriodResult(this.basis, this.preset, this.range);
  final ShipmentPeriodBasis basis;
  final ShipmentPeriodPreset preset;
  final DateTimeRange? range;
}

/// Libellés des préréglages de période — dépendent de la langue, jamais de
/// `const`/top-level figé.
Map<ShipmentPeriodPreset, String> _presetLabels(AppLocalizations l) => {
  ShipmentPeriodPreset.thisWeek: l.commonDateThisWeek,
  ShipmentPeriodPreset.thisMonth: l.commonDateThisMonthLong,
  ShipmentPeriodPreset.last3Months: l.shipmentPeriodLast3MonthsLabel,
  ShipmentPeriodPreset.thisYear: l.shipmentPeriodThisYearLabel,
  ShipmentPeriodPreset.all: l.shipmentPeriodAllLabel,
};

class ShipmentPeriodFilterSheet {
  static Future<ShipmentPeriodResult?> show(
    BuildContext context, {
    required ShipmentPeriodBasis basis,
    required ShipmentPeriodPreset preset,
    required DateTimeRange? range,
  }) {
    final basisN = ValueNotifier(basis);
    final presetN = ValueNotifier(preset);
    final rangeN = ValueNotifier(range);
    final l = context.l10n;
    final presetLabels = _presetLabels(l);

    return DonyBottomSheet.show<ShipmentPeriodResult>(
      context,
      title: l.shipmentPeriodFilterTitle,
      stickyBottom: DonyButton(
        label: l.commonApply,
        onPressed: () => Navigator.of(
          context,
          rootNavigator: true,
        ).pop(ShipmentPeriodResult(basisN.value, presetN.value, rangeN.value)),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([basisN, presetN, rangeN]),
        builder: (context, _) {
          final cs = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Row(
                  children: [
                    _BasisTab(
                      label: l.shipmentPeriodBasisDepartureLabel,
                      active: basisN.value == ShipmentPeriodBasis.departure,
                      onTap: () => basisN.value = ShipmentPeriodBasis.departure,
                    ),
                    _BasisTab(
                      label: l.shipmentPeriodBasisCreationLabel,
                      active: basisN.value == ShipmentPeriodBasis.creation,
                      onTap: () => basisN.value = ShipmentPeriodBasis.creation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.md),
              Wrap(
                spacing: DonySpacing.xs,
                runSpacing: DonySpacing.xs,
                children: [
                  for (final e in presetLabels.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: presetN.value == e.key,
                      onSelected: (_) {
                        presetN.value = e.key;
                        if (e.key != ShipmentPeriodPreset.custom) {
                          rangeN.value = null;
                        }
                      },
                    ),
                  ChoiceChip(
                    label: Text(
                      rangeN.value != null &&
                              presetN.value == ShipmentPeriodPreset.custom
                          ? l.shipmentPeriodCustomSelectedLabel
                          : l.shipmentPeriodCustomLabel,
                    ),
                    selected: presetN.value == ShipmentPeriodPreset.custom,
                    onSelected: (_) async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: rangeN.value,
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: Theme.of(
                              ctx,
                            ).colorScheme.copyWith(primary: cs.primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        rangeN.value = picked;
                        presetN.value = ShipmentPeriodPreset.custom;
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      basisN.dispose();
      presetN.dispose();
      rangeN.dispose();
    });
  }
}

class _BasisTab extends StatelessWidget {
  const _BasisTab({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
          decoration: BoxDecoration(
            color: active ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
