import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/home/presentation/widgets/evergreen_guidance_carousel.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _destinations = [
    ('SN', '🇸🇳', 'Dakar'), // i18n-ignore: nom de ville (donnée)
    ('CI', '🇨🇮', 'Abidjan'), // i18n-ignore: nom de ville (donnée)
    ('ML', '🇲🇱', 'Bamako'), // i18n-ignore: nom de ville (donnée)
    ('CM', '🇨🇲', 'Douala'), // i18n-ignore: nom de ville (donnée)
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Scaffold(
      appBar: DonyAppBar(title: l.settingsTitle),
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
              SettingsSectionHeader(l.settingsSectionAppearance),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: _themeIcon(prefs.themeMode),
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: l.settingsThemeLabel,
                    subtitle: l.settingsThemeSubtitle,
                    showDivider: false,
                    trailing: _disclosure(
                      context,
                      _themeLabel(l, prefs.themeMode),
                    ),
                    onTap: () => _showThemePicker(context, prefs.themeMode),
                  ),
                ],
              ),

              // ── LANGUE & COMMUNICATION ─────────────────────────────────
              SettingsSectionHeader(l.settingsSectionLanguage),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'languages',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: l.settingsLanguageTitle,
                    showDivider: false,
                    trailing: _disclosure(
                      context,
                      _languageLabel(context, prefs.languageCode),
                    ),
                    onTap: () =>
                        _showLanguagePicker(context, prefs.languageCode),
                  ),
                ],
              ),

              // ── DESTINATIONS FAVORITES ─────────────────────────────────
              SettingsSectionHeader(l.settingsSectionDestinations),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'map-pin',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: l.settingsDestinationsLabel,
                    showDivider: false,
                    trailing: _disclosure(
                      context,
                      _destinationsSummary(l, prefs.favDestinations),
                    ),
                    onTap: () => _showDestinationsPicker(context),
                  ),
                ],
              ),

              // ── SÉCURITÉ & DONNÉES ─────────────────────────────────────
              SettingsSectionHeader(l.settingsSectionSecurityData),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'lock',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: l.securityTitle,
                    subtitle: l.settingsSecuritySubtitle,
                    onTap: () => context.push('/settings/security'),
                  ),
                  DonyListTile(
                    iconAsset: 'eye-off',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: l.settingsPrivacyLabel,
                    subtitle: l.settingsPrivacySubtitle,
                    onTap: () => context.push('/settings/privacy'),
                  ),
                  DonyListTile(
                    iconAsset: 'folder',
                    iconColor: cs.error,
                    iconBgColor: cs.errorContainer,
                    label: l.settingsMyData,
                    subtitle: l.settingsMyDataSubtitle,
                    showDivider: false,
                    onTap: () => context.push('/settings/data'),
                  ),
                ],
              ),

              // ── PERSONNALISATION ───────────────────────────────────────
              SettingsSectionHeader(l.settingsSectionPersonalization),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'bell',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: l.settingsNotificationsLabel,
                    subtitle: l.settingsNotificationsSubtitle,
                    onTap: () => context.push('/settings/notifications'),
                  ),
                  DonyListTile(
                    iconAsset: 'sliders-horizontal',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: l.settingsPreferencesLabel,
                    subtitle: l.settingsPreferencesSubtitle,
                    onTap: () => context.push('/settings/preferences'),
                  ),
                  DonyListTile(
                    iconAsset: 'accessibility',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: l.settingsAccessibilityLabel,
                    subtitle: l.settingsAccessibilitySubtitle,
                    onTap: () => context.push('/settings/accessibility'),
                  ),
                  DonyListTile(
                    iconAsset: 'refresh-cw',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: l.settingsResetGuidanceLabel,
                    subtitle: l.settingsResetGuidanceSubtitle,
                    showDivider: false,
                    onTap: () => _resetGuidanceCards(context),
                  ),
                ],
              ),

              // ── INFORMATIONS ───────────────────────────────────────────
              SettingsSectionHeader(l.settingsSectionInformation),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'file-text',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: l.settingsTermsLabel,
                    onTap: () => context.push('/legal/terms'),
                  ),
                  DonyListTile(
                    iconAsset: 'file-badge',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: l.settingsPrivacyPolicyLabel,
                    onTap: () => context.push('/legal/privacy'),
                  ),
                  DonyListTile(
                    iconAsset: 'flag',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: l.settingsReportProblemLabel,
                    subtitle: l.settingsReportProblemSubtitle,
                    onTap: () => context.push('/settings/report-incident'),
                  ),
                  DonyListTile(
                    iconAsset: 'bug',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: l.diagnosticsTitle,
                    subtitle: l.settingsDiagnosticsSubtitle,
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
      message: context.l10n.settingsResetGuidanceSnackbar,
      type: DonySnackbarType.success,
    );
  }

  // ── Helpers thème / destinations ──────────────────────────────────────────
  String _themeIcon(String mode) => switch (mode) {
    'light' => 'sun',
    'dark' => 'moon',
    _ => 'sun-moon',
  };

  String _themeLabel(AppLocalizations l, String mode) => switch (mode) {
    'light' => l.settingsThemeLight,
    'dark' => l.settingsThemeDark,
    _ => l.settingsThemeAuto,
  };

  String _languageLabel(
    BuildContext context,
    String stored,
  ) => switch (AppL10n.effectiveChoice(stored)) {
    'fr' => 'Français', // i18n-ignore: nom de la langue dans sa propre langue
    'en' => 'English', // i18n-ignore: nom de la langue dans sa propre langue
    _ => context.l10n.settingsLanguagePhone,
  };

  String _destinationsSummary(AppLocalizations l, List<String> codes) {
    if (codes.isEmpty) {
      return l.settingsNoDestination;
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
    final l = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in [
              ('light', l.settingsThemeLight),
              ('dark', l.settingsThemeDark),
              ('system', l.settingsThemeAuto),
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
    final bloc = context.read<AppPreferencesBloc>();
    final selected = AppL10n.effectiveChoice(current);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in [
              (
                UserPreferencesModel.kLanguageSystem,
                sheetCtx.l10n.settingsLanguagePhone,
              ),
              (
                'fr',
                'Français', // i18n-ignore: nom de la langue dans sa propre langue
              ),
              if (AppL10n.englishEnabled)
                (
                  'en',
                  'English', // i18n-ignore: nom de la langue dans sa propre langue
                ),
            ])
              ListTile(
                title: Text(opt.$2),
                trailing: selected == opt.$1
                    ? DonyIcon(
                        'check',
                        color: Theme.of(sheetCtx).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  bloc.add(LanguageChanged(opt.$1));
                  Navigator.pop(sheetCtx);
                },
              ),
          ],
        ),
      ),
    );
  }
}
