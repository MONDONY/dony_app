import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Contrôle de capacité : 4 chips single-select (DonyChip) + slider en mode custom.
///
/// Choix DonyChip vs Container+GestureDetector :
///   - DonyChip couvre exactement le besoin (sélection unique, animation,
///     couleurs sémantiques, touch target ≥ 44px via padding interne).
///   - Évite de dupliquer la logique de style déjà centralisée dans le DS.
///   - Note : DonyChip utilise `DonyRadius.full` (pill) — cohérent avec les chips
///     partout dans l'app. Le plan de référence utilisait `DonyRadius.xl` qui est
///     visuellement identique pour des textes courts.
class CapacityControl extends StatelessWidget {
  const CapacityControl({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
      buildWhen: (prev, curr) =>
          prev.capacityUnit != curr.capacityUnit ||
          prev.availableKg != curr.availableKg,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capacité disponible', style: tt.titleMedium),
            const SizedBox(height: DonySpacing.sm),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: CapacityUnit.values.map((unit) {
                return DonyChip(
                  label: unit.label,
                  selected: state.capacityUnit == unit,
                  onTap: () => context
                      .read<AnnouncementFormBloc>()
                      .add(CapacityUnitChanged(unit)),
                );
              }).toList(),
            ),
            const SizedBox(height: DonySpacing.md),
            _buildBody(context, state, tt),
          ],
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AnnouncementFormState state,
    TextTheme tt,
  ) {
    final cs = Theme.of(context).colorScheme;

    switch (state.capacityUnit) {
      case CapacityUnit.suitcase23kg:
      case CapacityUnit.suitcase32kg:
        return _InfoCard(
          icon: DonyIcons.suitcase,
          title: 'Vous offrez ${state.capacityUnit.maxKg!.toInt()} kg',
          subtitle: 'Une valise standard en soute',
        );
      case CapacityUnit.kgFree:
        return const _InfoCard(
          icon: DonyIcons.infinity,
          title: 'Sans limite précise',
          subtitle: "L'expéditeur verra « kilo disponible »",
        );
      case CapacityUnit.custom:
        final kg = (state.availableKg ?? 1).clamp(1, 30).toDouble();
        return Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Vous offrez', style: tt.titleMedium),
                  Text(
                    '${kg.toInt()} kg',
                    style: tt.headlineMedium?.copyWith(color: cs.primary),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xs),
              Slider(
                value: kg,
                min: 1,
                max: 30,
                divisions: 29,
                onChanged: (v) => context
                    .read<AnnouncementFormBloc>()
                    .add(AvailableKgChanged(v)),
              ),
            ],
          ),
        );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 24),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleMedium),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
