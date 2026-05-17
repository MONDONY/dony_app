import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Contrôle de capacité : 4 chips single-select (DonyChip) + corps adapté par mode.
///
/// - Presets valise (23/32 kg) : compteur ± sans plafond, availableKg = quantité × unitKg.
/// - Kg libre : carte info statique (inchangé).
/// - Personnalisé : champ de saisie libre (kg entier, minimum 1, sans maximum).
///
/// `StatefulWidget` requis pour :
///   - `TextEditingController` du mode personnalisé (créé en initState, disposé en dispose).
///   - Synchronisation controller ↔ état BLoC lors du changement de mode.
class CapacityControl extends StatefulWidget {
  const CapacityControl({super.key});

  @override
  State<CapacityControl> createState() => _CapacityControlState();
}

class _CapacityControlState extends State<CapacityControl> {
  late final TextEditingController _customKgController;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<AnnouncementFormBloc>();
    final initialKg = bloc.state.availableKg;
    _customKgController = TextEditingController(
      text: initialKg != null && initialKg >= 1 ? initialKg.toInt().toString() : '',
    );
  }

  @override
  void dispose() {
    _customKgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AnnouncementFormBloc, AnnouncementFormState>(
      listenWhen: (prev, curr) => prev.capacityUnit != curr.capacityUnit,
      listener: (context, state) {
        // Quand on passe en mode personnalisé, pré-remplir le champ avec
        // la valeur courante du bloc (ou vider si null/invalide).
        if (state.capacityUnit == CapacityUnit.custom) {
          final kg = state.availableKg;
          final text = kg != null && kg >= 1 ? kg.toInt().toString() : '';
          if (_customKgController.text != text) {
            _customKgController.text = text;
          }
        }
      },
      buildWhen: (prev, curr) =>
          prev.capacityUnit != curr.capacityUnit ||
          prev.availableKg != curr.availableKg,
      builder: (context, state) {
        final tt = Theme.of(context).textTheme;
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
            _buildBody(context, state),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AnnouncementFormState state) {
    switch (state.capacityUnit) {
      case CapacityUnit.suitcase23kg:
      case CapacityUnit.suitcase32kg:
        return _SuitcaseStepperCard(state: state);
      case CapacityUnit.kgFree:
        return const _InfoCard(
          icon: DonyIcons.infinity,
          title: 'Sans limite précise',
          subtitle: "L'expéditeur verra « kilo disponible »",
        );
      case CapacityUnit.custom:
        return _CustomKgCard(controller: _customKgController);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte valise avec compteur ±
// ─────────────────────────────────────────────────────────────────────────────

class _SuitcaseStepperCard extends StatelessWidget {
  const _SuitcaseStepperCard({required this.state});

  final AnnouncementFormState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final unitKg = state.capacityUnit.maxKg!;
    final totalKg = state.availableKg ?? unitKg;
    final quantite = ((totalKg / unitKg).round()).clamp(1, 999999);
    final totalDisplay = (quantite * unitKg).toInt();
    final valiseLabel = quantite == 1 ? 'valise' : 'valises';

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
          // Ligne icône + titre total
          Row(
            children: [
              Icon(DonyIcons.suitcase, color: cs.primary, size: 24),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vous offrez $totalDisplay kg',
                      style: tt.titleMedium,
                    ),
                    Text(
                      '$quantite $valiseLabel de ${unitKg.toInt()} kg',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          // Compteur ±
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouton −
              _StepperButton(
                icon: DonyIcons.minus,
                enabled: quantite > 1,
                semanticLabel: 'Diminuer la quantité',
                onPressed: quantite > 1
                    ? () => context.read<AnnouncementFormBloc>().add(
                          AvailableKgChanged((quantite - 1) * unitKg),
                        )
                    : null,
              ),
              // Affichage quantité
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.xl,
                ),
                child: Text(
                  '$quantite',
                  style: tt.headlineMedium?.copyWith(color: cs.primary),
                ),
              ),
              // Bouton +
              _StepperButton(
                icon: DonyIcons.add,
                enabled: true,
                semanticLabel: 'Augmenter la quantité',
                onPressed: () => context.read<AnnouncementFormBloc>().add(
                      AvailableKgChanged((quantite + 1) * unitKg),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        style: IconButton.styleFrom(
          backgroundColor: enabled
              ? cs.primary.withValues(alpha: 0.08)
              : cs.onSurface.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte personnalisé — saisie libre
// ─────────────────────────────────────────────────────────────────────────────

class _CustomKgCard extends StatelessWidget {
  const _CustomKgCard({required this.controller});

  final TextEditingController controller;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyTextField(
            controller: controller,
            label: 'Capacité (kg)',
            prefixIcon: DonyIcons.suitcase,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 1) {
                context
                    .read<AnnouncementFormBloc>()
                    .add(AvailableKgChanged(parsed.toDouble()));
              }
            },
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Indiquez la capacité totale que vous offrez',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte info statique (kgFree)
// ─────────────────────────────────────────────────────────────────────────────

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
