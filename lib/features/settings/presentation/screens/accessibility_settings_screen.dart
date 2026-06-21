import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Accessibilité'),
      body: BlocBuilder<AccessibilityBloc, AccessibilityState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg, DonySpacing.lg, DonySpacing.lg, DonySpacing.huge),
          children: [
            const SettingsSectionHeader('TEXTE'),
            SettingsFlatGroup(
              children: [
                Padding(
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
              ],
            ),
            const SizedBox(height: DonySpacing.lg),
            const SettingsSectionHeader('AFFICHAGE'),
            SettingsFlatGroup(
              children: [
                DonyListTile(
                  iconAsset: 'contrast',
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
                  iconAsset: 'circle-play',
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
              ],
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
            .slideY(begin: 0.04, duration: 280.ms, curve: Curves.easeOutCubic),
      ),
    );
  }
}
