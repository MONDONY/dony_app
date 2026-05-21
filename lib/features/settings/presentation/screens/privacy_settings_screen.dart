import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Confidentialité'),
      body: BlocBuilder<PrivacySettingsBloc, PrivacySettingsState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.lg,
            DonySpacing.lg,
            DonySpacing.huge,
          ),
          children: [
            const _SectionLabel('VISIBILITÉ'),
            DonyListSection(
              tiles: [
                DonyListTile(
                  icon: Icons.public_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Visibilité du profil',
                  subtitle: state.profileVisibility == 'public'
                      ? 'Visible dans les résultats de matching'
                      : 'Visible uniquement par tes partenaires actifs',
                  trailing: _VisibilityChip(
                    label: state.profileVisibility == 'public'
                        ? 'Public'
                        : 'Limité',
                    cs: cs,
                  ),
                  onTap: () =>
                      _showVisibilityPicker(context, state.profileVisibility),
                ),
                DonyListTile(
                  icon: Icons.phone_locked_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Masquer mon numéro',
                  subtitle:
                      'Les autres utilisateurs ne verront pas ton numéro',
                  trailing: Switch(
                    value: state.hidePhoneNumber,
                    activeThumbColor: cs.primary,
                    onChanged: (_) => context
                        .read<PrivacySettingsBloc>()
                        .add(const HidePhoneToggled()),
                  ),
                  onTap: () => context
                      .read<PrivacySettingsBloc>()
                      .add(const HidePhoneToggled()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVisibilityPicker(BuildContext context, String current) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bloc = context.read<PrivacySettingsBloc>();

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: DonySpacing.base),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius:
                        BorderRadius.circular(DonyRadius.full),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  0,
                  DonySpacing.lg,
                  DonySpacing.base,
                ),
                child: Text(
                  'Visibilité du profil',
                  style: tt.titleLarge,
                ),
              ),
              _VisibilityOption(
                title: 'Public',
                subtitle: 'Visible dans les résultats de matching',
                isSelected: current == 'public',
                onTap: () {
                  bloc.add(const ProfileVisibilityChanged('public'));
                  Navigator.pop(sheetCtx);
                },
                cs: cs,
              ),
              _VisibilityOption(
                title: 'Limité',
                subtitle:
                    'Visible uniquement par tes partenaires actifs',
                isSelected: current == 'limited',
                onTap: () {
                  bloc.add(const ProfileVisibilityChanged('limited'));
                  Navigator.pop(sheetCtx);
                },
                cs: cs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets privés ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.xs,
        0,
        DonySpacing.xs,
        DonySpacing.sm,
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: DonySpacing.xs),
        Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
      ],
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.cs,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.base,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: DonySpacing.sm),
              Icon(Icons.check_rounded, color: cs.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
