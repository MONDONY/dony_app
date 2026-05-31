import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _destinations = [
    ('SN', '🇸🇳', 'Dakar'),
    ('CI', '🇨🇮', 'Abidjan'),
    ('ML', '🇲🇱', 'Bamako'),
    ('CM', '🇨🇲', 'Douala'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Paramètres'),
      body: BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
        builder: (context, prefsState) {
          final prefs = prefsState.preferences;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.huge),
            children: [

              // ── APPARENCE ──────────────────────────────────────────────
              const _SectionLabel('APPARENCE'),
              _ThemeSelector(
                current: prefs.themeMode,
                onChanged: (mode) => context
                    .read<AppPreferencesBloc>()
                    .add(ThemeChanged(mode)),
              ),
              const SizedBox(height: DonySpacing.lg),

              // ── LANGUE & COMMUNICATION ─────────────────────────────────
              const _SectionLabel('LANGUE & COMMUNICATION'),
              DonyListSection(tiles: [
                DonyListTile(
                  icon: Icons.translate_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Langue',
                  trailing: Text(
                    prefs.languageCode == 'fr' ? 'Français' : 'English',
                    style: tt.labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  onTap: () =>
                      _showLanguagePicker(context, prefs.languageCode),
                ),
              ]),
              const SizedBox(height: DonySpacing.lg),

              // ── DESTINATIONS FAVORITES ──────────────────────────────────
              const _SectionLabel('DESTINATIONS FAVORITES'),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      BorderRadius.circular(DonyRadius.card),
                  border: Border.all(color: cs.outline),
                ),
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Wrap(
                  spacing: DonySpacing.sm,
                  runSpacing: DonySpacing.sm,
                  children: _destinations.map((dest) {
                    final (code, flag, city) = dest;
                    final isSelected =
                        prefs.favDestinations.contains(code);
                    return GestureDetector(
                      onTap: () => context
                          .read<AppPreferencesBloc>()
                          .add(DestinationToggled(code)),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.base,
                            vertical: DonySpacing.sm),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                              DonyRadius.full),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : cs.outline,
                          ),
                        ),
                        child: Text(
                          '$flag $city',
                          style: tt.labelMedium?.copyWith(
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: DonySpacing.lg),

              // ── SÉCURITÉ & DONNÉES ──────────────────────────────────────
              const _SectionLabel('SÉCURITÉ & DONNÉES'),
              DonyListSection(tiles: [
                DonyListTile(
                  icon: Icons.lock_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Sécurité',
                  subtitle: 'Biométrie, PIN, sessions',
                  onTap: () => context.push('/settings/security'),
                ),
                DonyListTile(
                  icon: Icons.visibility_off_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Confidentialité',
                  subtitle: 'Visibilité profil, numéro',
                  onTap: () => context.push('/settings/privacy'),
                ),
                DonyListTile(
                  icon: Icons.folder_rounded,
                  iconColor: cs.error,
                  iconBgColor: cs.errorContainer,
                  label: 'Mes données',
                  subtitle: 'Export, suppression du compte',
                  onTap: () => context.push('/settings/data'),
                ),
              ]),
              const SizedBox(height: DonySpacing.lg),

              // ── PERSONNALISATION ────────────────────────────────────────
              const _SectionLabel('PERSONNALISATION'),
              DonyListSection(tiles: [
                DonyListTile(
                  icon: Icons.notifications_none_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Notifications',
                  subtitle: "Par type d'alerte",
                  onTap: () =>
                      context.push('/settings/notifications'),
                ),
                DonyListTile(
                  icon: Icons.tune_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Préférences',
                  subtitle: 'kg/lbs, devise, rayon de pickup',
                  onTap: () =>
                      context.push('/settings/preferences'),
                ),
                DonyListTile(
                  icon: Icons.accessibility_new_rounded,
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Accessibilité',
                  subtitle: 'Contraste, taille de police',
                  onTap: () =>
                      context.push('/settings/accessibility'),
                ),
              ]),
              const SizedBox(height: DonySpacing.lg),

              // ── INFORMATIONS ────────────────────────────────────────────
              const _SectionLabel('INFORMATIONS'),
              DonyListSection(tiles: [
                DonyListTile(
                  icon: Icons.article_outlined,
                  iconColor: cs.onSurfaceVariant,
                  iconBgColor: cs.surfaceContainerHighest,
                  label: 'CGU',
                  onTap: () =>
                      context.push('/settings/legal/terms'),
                ),
                DonyListTile(
                  icon: Icons.policy_outlined,
                  iconColor: cs.onSurfaceVariant,
                  iconBgColor: cs.surfaceContainerHighest,
                  label: 'Politique de confidentialité',
                  onTap: () =>
                      context.push('/settings/legal/privacy'),
                ),
                DonyListTile(
                  icon: Icons.bug_report_outlined,
                  iconColor: cs.onSurfaceVariant,
                  iconBgColor: cs.surfaceContainerHighest,
                  label: 'Diagnostics',
                  subtitle: 'Version, signaler un bug',
                  onTap: () =>
                      context.push('/settings/diagnostics'),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, String current) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Français'),
              trailing:
                  current == 'fr' ? const Icon(Icons.check) : null,
              onTap: () {
                context
                    .read<AppPreferencesBloc>()
                    .add(const LanguageChanged('fr'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              trailing:
                  current == 'en' ? const Icon(Icons.check) : null,
              onTap: () {
                context
                    .read<AppPreferencesBloc>()
                    .add(const LanguageChanged('en'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  IconData get _icon => switch (current) {
        'light' => Icons.light_mode_rounded,
        'dark'  => Icons.dark_mode_rounded,
        _       => Icons.brightness_auto_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DonyCard(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                child: Icon(_icon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: DonySpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thème', style: tt.titleMedium),
                  Text(
                    'Prioritaire sur le réglage système',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'light',
                  label: Text('Clair'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment<String>(
                  value: 'dark',
                  label: Text('Sombre'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment<String>(
                  value: 'system',
                  label: Text('Auto'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
              ],
              selected: {current},
              onSelectionChanged: (s) => onChanged(s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: cs.primaryContainer,
                selectedForegroundColor: cs.primary,
                foregroundColor: cs.onSurfaceVariant,
              ),
              showSelectedIcon: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DonySpacing.xs, 0, DonySpacing.xs, DonySpacing.sm),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
