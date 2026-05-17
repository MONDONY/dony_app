import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CapacitySelector extends StatelessWidget {
  const CapacitySelector({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
      buildWhen: (prev, curr) => prev.capacityUnit != curr.capacityUnit,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capacité',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: CapacityUnit.values.map((unit) {
                final isSelected = state.capacityUnit == unit;
                final isLast = unit == CapacityUnit.values.last;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => context
                        .read<AnnouncementFormBloc>()
                        .add(CapacityUnitChanged(unit)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin:
                          EdgeInsets.only(right: isLast ? 0 : DonySpacing.xs),
                      padding: const EdgeInsets.symmetric(
                        vertical: DonySpacing.sm,
                        horizontal: DonySpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? cs.primary : cs.surface,
                        borderRadius:
                            BorderRadius.circular(DonyRadius.lg),
                        border: Border.all(
                          color: isSelected ? cs.primary : cs.outline,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        unit.label,
                        textAlign: TextAlign.center,
                        style: tt.labelSmall?.copyWith(
                          color: isSelected
                              ? DonyColors.white
                              : cs.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
