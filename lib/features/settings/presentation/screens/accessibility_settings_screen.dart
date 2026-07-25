import 'package:app_settings/app_settings.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_preview_card.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_slider_row.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_tristate_row.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DonyAppBar(title: 'Accessibilité'),
      body: BlocBuilder<AccessibilityBloc, AccessibilityState>(
        builder: (context, state) {
          final bloc = context.read<AccessibilityBloc>();
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.lg,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              A11yPreviewCard(state: state),
              const SizedBox(height: DonySpacing.xl),

              const SettingsSectionHeader('TEXTE'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'smartphone',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Suivre les réglages du téléphone',
                    subtitle:
                        'La taille du texte suit celle définie dans votre téléphone',
                    trailing: Switch(
                      value: state.followSystemTextScale,
                      activeThumbColor: cs.primary,
                      onChanged: (v) =>
                          bloc.add(FollowSystemTextScaleToggled(v)),
                    ),
                    onTap: () => bloc.add(FollowSystemTextScaleToggled(
                        !state.followSystemTextScale)),
                  ),
                  A11ySliderRow(
                    value: state.textScaleFactor,
                    enabled: !state.followSystemTextScale,
                    onChanged: (v) => bloc.add(TextScaleFactorChanged(v)),
                  ),
                  DonyListTile(
                    iconAsset: 'square-pen',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Texte en gras',
                    subtitle: 'Épaissit tous les textes de l\'application',
                    showDivider: false,
                    trailing: Switch(
                      value: state.boldText,
                      activeThumbColor: cs.primary,
                      onChanged: (v) => bloc.add(BoldTextToggled(v)),
                    ),
                    onTap: () => bloc.add(BoldTextToggled(!state.boldText)),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.lg),

              const SettingsSectionHeader('AFFICHAGE'),
              SettingsFlatGroup(
                children: [
                  A11yTristateRow(
                    iconAsset: 'contrast',
                    label: 'Contraste élevé',
                    subtitle:
                        'Renforce le texte, les bordures et les séparateurs',
                    sheetTitle: 'Contraste élevé',
                    value: state.highContrast,
                    onChanged: (v) => bloc.add(HighContrastModeChanged(v)),
                  ),
                  DonyListTile(
                    iconAsset: 'link',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Souligner les liens',
                    subtitle:
                        'Les liens ne sont plus signalés par la couleur seule',
                    trailing: Switch(
                      value: state.underlineLinks,
                      activeThumbColor: cs.primary,
                      onChanged: (v) => bloc.add(UnderlineLinksToggled(v)),
                    ),
                    onTap: () =>
                        bloc.add(UnderlineLinksToggled(!state.underlineLinks)),
                  ),
                  DonyListTile(
                    iconAsset: 'tag',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Renforcer les étiquettes',
                    subtitle:
                        'Ajoute une icône et un mot aux statuts signalés par une couleur',
                    showDivider: false,
                    trailing: Switch(
                      value: state.reinforceLabels,
                      activeThumbColor: cs.primary,
                      onChanged: (v) => bloc.add(ReinforceLabelsToggled(v)),
                    ),
                    onTap: () => bloc
                        .add(ReinforceLabelsToggled(!state.reinforceLabels)),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.lg),

              const SettingsSectionHeader('MOUVEMENT'),
              SettingsFlatGroup(
                children: [
                  A11yTristateRow(
                    iconAsset: 'circle-play',
                    label: 'Réduire les animations',
                    subtitle:
                        'Supprime les transitions, les apparitions et les effets de chargement',
                    sheetTitle: 'Réduire les animations',
                    value: state.reduceMotion,
                    showDivider: false,
                    onChanged: (v) => bloc.add(ReduceMotionModeChanged(v)),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.lg),

              const SettingsSectionHeader('MESSAGES ET ACTIONS'),
              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'messages-square',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Garder les messages affichés',
                    subtitle:
                        'Les messages restent visibles jusqu\'à ce que vous les fermiez',
                    trailing: Switch(
                      value: state.persistentMessages,
                      activeThumbColor: cs.primary,
                      onChanged: (v) => bloc.add(PersistentMessagesToggled(v)),
                    ),
                    onTap: () => bloc.add(
                        PersistentMessagesToggled(!state.persistentMessages)),
                  ),
                  DonyListTile(
                    iconAsset: 'shield-check',
                    iconColor: cs.primary,
                    iconBgColor: cs.primaryContainer,
                    label: 'Confirmer les actions importantes',
                    subtitle:
                        'Demande une confirmation avant un paiement, une annulation ou une suppression',
                    showDivider: false,
                    trailing: Switch(
                      value: state.confirmImportantActions,
                      activeThumbColor: cs.primary,
                      onChanged: (v) =>
                          bloc.add(ConfirmImportantActionsToggled(v)),
                    ),
                    onTap: () => bloc.add(ConfirmImportantActionsToggled(
                        !state.confirmImportantActions)),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),

              SettingsFlatGroup(
                children: [
                  DonyListTile(
                    iconAsset: 'sliders-horizontal',
                    iconColor: cs.onSurfaceVariant,
                    iconBgColor: cs.surfaceContainerHighest,
                    label: 'Ouvrir les réglages du téléphone',
                    subtitle:
                        'Taille de texte, contraste et animations du système',
                    showDivider: false,
                    trailing: Icon(Icons.open_in_new_rounded,
                        size: 18, color: cs.onSurfaceVariant),
                    onTap: () => AppSettings.openAppSettings(
                        type: AppSettingsType.accessibility),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.base),

              Center(
                child: TextButton(
                  onPressed: () => _confirmReset(context, bloc),
                  child: Text(
                    'Tout réinitialiser',
                    style: tt.labelLarge?.copyWith(color: cs.error),
                  ),
                ),
              ),
            ],
            )
                .animate()
                .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
                .slideY(
                    begin: 0.04, duration: 280.ms, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(
      BuildContext context, AccessibilityBloc bloc) async {
    final ok = await DonyDialog.show(
      context,
      title: 'Tout réinitialiser',
      message:
          'Tous les réglages d\'accessibilité reviendront à leur valeur d\'origine.',
      variant: DonyDialogVariant.destructive,
    );
    if (ok ?? false) {
      bloc.add(const AccessibilityResetRequested());
    }
  }
}
