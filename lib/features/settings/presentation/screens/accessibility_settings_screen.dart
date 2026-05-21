import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  static const _scaleOptions = [
    ('small', 'Petite'),
    ('normal', 'Normale'),
    ('large', 'Grande'),
    ('xlarge', 'Très grande'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Accessibilité'),
      body: BlocBuilder<AccessibilityBloc, AccessibilityState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg, DonySpacing.lg, DonySpacing.lg, DonySpacing.huge),
          children: [
            _SectionLabel('TEXTE', cs: cs),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(color: cs.outline),
              ),
              padding: const EdgeInsets.all(DonySpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Taille du texte',
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: DonySpacing.sm),
                  SegmentedButton<String>(
                    segments: _scaleOptions
                        .map((o) =>
                            ButtonSegment(value: o.$1, label: Text(o.$2)))
                        .toList(),
                    selected: {state.textScale},
                    onSelectionChanged: (s) => context
                        .read<AccessibilityBloc>()
                        .add(TextScaleChanged(s.first)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DonySpacing.lg),
            _SectionLabel('AFFICHAGE', cs: cs),
            DonyListSection(tiles: [
              DonyListTile(
                icon: Icons.contrast_rounded,
                iconColor: cs.primary,
                iconBgColor: cs.primaryContainer,
                label: 'Contraste élevé',
                trailing: Switch(
                  value: state.highContrast,
                  activeThumbColor: cs.primary,
                  onChanged: (_) => context
                      .read<AccessibilityBloc>()
                      .add(const HighContrastToggled()),
                ),
                onTap: () => context
                    .read<AccessibilityBloc>()
                    .add(const HighContrastToggled()),
              ),
              DonyListTile(
                icon: Icons.animation_rounded,
                iconColor: cs.onSurfaceVariant,
                iconBgColor: cs.surfaceContainerHighest,
                label: 'Réduire les animations',
                trailing: Switch(
                  value: state.reduceAnimations,
                  activeThumbColor: cs.primary,
                  onChanged: (_) => context
                      .read<AccessibilityBloc>()
                      .add(const ReduceAnimationsToggled()),
                ),
                showDivider: false,
                onTap: () => context
                    .read<AccessibilityBloc>()
                    .add(const ReduceAnimationsToggled()),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            DonySpacing.xs, 0, DonySpacing.xs, DonySpacing.sm),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.2,
            )),
      );
}
