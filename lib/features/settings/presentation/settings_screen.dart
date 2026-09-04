import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/home/presentation/widgets/evergreen_guidance_carousel.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
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

    return Scaffold(
      appBar: const DonyAppBar(title: 'Paramètres'),
      body: BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
        builder: (context, prefsState) {
          final prefs = prefsState.preferences;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base,
              DonySpacing.sm,
              DonySpacing.base,
              DonySpacing.huge,
            ),
            children: [
              // ── APPARENCE ──────────────────────────────────────────────
              const SettingsSectionHeader('APPARENCE'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: _themeIcon(prefs.themeMode),
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Thème',
                    subtitle: 'Prioritaire sur le réglage système',
                    showDivider: false,
                    trailing: _disclosure(
                      context,
                      _themeLabel(prefs.themeMode),
                    ),
                    onTap: () => _showThemePicker(context, prefs.themeMode),
                  ),
                ],
              ),

              // ── LANGUE & COMMUNICATION ─────────────────────────────────
              const SettingsSectionHeader('LANGUE & COMMUNICATION'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'languages',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Langue',
                    showDivider: false,
                    trailing: _disclosure(
                      context,
                      prefs.languageCode == 'fr' ? 'Français' : 'English',
                    ),
                    onTap: () =>
                        _showLanguagePicker(context, prefs.languageCode),
                  ),
                ],
              ),

              // ── DESTINATIONS FAVORITES ─────────────────────────────────
              const SettingsSectionHeader('DESTINATIONS FAVORITES'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'map-pin',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Destinations',
                    showDivider: false,
                    trailing: _disclosure(
                      context,
                      _destinationsSummary(prefs.favDestinations),
                    ),
                    onTap: () => _showDestinationsPicker(context),
                  ),
                ],
              ),

              // ── SÉCURITÉ & DONNÉES ─────────────────────────────────────
              const SettingsSectionHeader('SÉCURITÉ & DONNÉES'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'lock',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Sécurité',
                    subtitle: 'Biométrie, PIN, sessions',
                    onTap: () => context.push('/settings/security'),
                  ),
                  DonyListTile(
                    iconAsset: 'eye-off',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Confidentialité',
                    subtitle: 'Visibilité profil, numéro',
                    onTap: () => context.push('/settings/privacy'),
                  ),
                  DonyListTile(
                    iconAsset: 'folder',
                    iconColor: cs.error,
                    iconBgColor: cs.errorContainer,
                    label: 'Mes données',
                    subtitle: 'Export RGPD',
                    showDivider: false,
                    onTap: () => context.push('/settings/data'),
                  ),
                ],
              ),

              // ── PERSONNALISATION ───────────────────────────────────────
              const SettingsSectionHeader('PERSONNALISATION'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'bell',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Notifications',
                    subtitle: "Par type d'alerte",
                    onTap: () => context.push('/settings/notifications'),
                  ),
                  DonyListTile(
                    iconAsset: 'sliders-horizontal',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Préférences',
                    subtitle: 'kg/lbs, devise, rayon de collecte',
                    onTap: () => context.push('/settings/preferences'),
                  ),
                  DonyListTile(
                    iconAsset: 'accessibility',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Accessibilité',
                    subtitle: 'Contraste, taille de police',
                    onTap: () => context.push('/settings/accessibility'),
                  ),
                  DonyListTile(
                    iconAsset: 'refresh-cw',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Réafficher les suggestions',
                    subtitle:
                        'Fait revenir les cartes fermées (écran Recherche)',
                    showDivider: false,
                    onTap: () => _resetGuidanceCards(context),
                  ),
                ],
              ),

              // ── INFORMATIONS ───────────────────────────────────────────
              const SettingsSectionHeader('INFORMATIONS'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'file-text',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: 'CGU',
                    onTap: () => context.push('/legal/terms'),
                  ),
                  DonyListTile(
                    iconAsset: 'file-badge',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: 'Politique de confidentialité',
                    onTap: () => context.push('/legal/privacy'),
                  ),
                  DonyListTile(
                    iconAsset: 'flag',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: 'Signaler un problème',
                    subtitle: 'Incident, bug, litige (avec captures)',
                    onTap: () => context.push('/settings/report-incident'),
                  ),
                  DonyListTile(
                    iconAsset: 'bug',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: 'Diagnostics',
                    subtitle: 'Version, signaler un bug',
                    showDivider: false,
                    onTap: () => context.push('/settings/diagnostics'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Efface les flags de fermeture manuelle (X) du carousel de guidance de
  /// l'écran Recherche ainsi que ceux des `ContextualTutorialCard` semées
  /// dans le reste de l'app (une clé par tutoriel) : sans ça, une fois
  /// toutes les cartes fermées, ces zones de suggestions restent vides pour
  /// toujours, sans moyen de revenir en arrière.
  void _resetGuidanceCards(BuildContext context) {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.settingsGuidanceCardsReset,
      ),
    );
    final hive = getIt<HiveService>();
    for (final id in EvergreenGuidanceCarousel.guidanceSlideIds) {
      unawaited(
        hive.userPrefs.put(
          '${HiveService.kGuidanceSlideDismissedPrefix}$id',
          false,
        ),
      );
    }
    final tutorialKeys = hive.userPrefs.keys.where(
      (key) =>
          key is String &&
          key.startsWith(HiveService.kContextualTutorialDismissedPrefix),
    );
    for (final key in tutorialKeys.toList()) {
      unawaited(hive.userPrefs.delete(key));
    }
    DonySnackbar.show(
      context,
      message: 'Suggestions et tutoriels réaffichés.',
      type: DonySnackbarType.success,
    );
  }

  // ── Helpers thème / destinations ──────────────────────────────────────────
  String _themeIcon(String mode) => switch (mode) {
    'light' => 'sun',
    'dark' => 'moon',
    _ => 'sun-moon',
  };

  String _themeLabel(String mode) => switch (mode) {
    'light' => 'Clair',
    'dark' => 'Sombre',
    _ => 'Auto',
  };

  String _destinationsSummary(List<String> codes) {
    if (codes.isEmpty) {
      return 'Aucune';
    }
    final names = _destinations
        .where((d) => codes.contains(d.$1))
        .map((d) => d.$3)
        .toList();
    if (names.length <= 1) {
      return names.join();
    }
    return '${names.first} +${names.length - 1}';
  }

  Widget _disclosure(BuildContext context, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: DonySpacing.xs),
        DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
      ],
    );
  }

  void _showThemePicker(BuildContext context, String current) {
    final bloc = context.read<AppPreferencesBloc>();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in const [
              ('light', 'Clair'),
              ('dark', 'Sombre'),
              ('system', 'Auto'),
            ])
              ListTile(
                title: Text(opt.$2),
                trailing: current == opt.$1
                    ? DonyIcon(
                        'check',
                        color: Theme.of(sheetCtx).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  bloc.add(ThemeChanged(opt.$1));
                  Navigator.pop(sheetCtx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDestinationsPicker(BuildContext context) {
    final bloc = context.read<AppPreferencesBloc>();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => BlocProvider<AppPreferencesBloc>.value(
        value: bloc,
        child: SafeArea(
          child: BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
            builder: (ctx, state) {
              final selected = state.preferences.favDestinations;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final dest in _destinations)
                    ListTile(
                      title: Text('${dest.$2} ${dest.$3}'),
                      trailing: selected.contains(dest.$1)
                          ? DonyIcon(
                              'check',
                              color: Theme.of(ctx).colorScheme.primary,
                            )
                          : null,
                      onTap: () => bloc.add(DestinationToggled(dest.$1)),
                    ),
                ],
              );
            },
          ),
        ),
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
              trailing: current == 'fr'
                  ? DonyIcon(
                      'check',
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                context.read<AppPreferencesBloc>().add(
                  const LanguageChanged('fr'),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              trailing: current == 'en'
                  ? DonyIcon(
                      'check',
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                context.read<AppPreferencesBloc>().add(
                  const LanguageChanged('en'),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
