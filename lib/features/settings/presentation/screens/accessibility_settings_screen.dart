import 'package:app_settings/app_settings.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_preview_card.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_slider_row.dart';
import 'package:dony/features/settings/presentation/widgets/a11y_tristate_row.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: DonyAppBar(title: l.a11yTitle),
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
            child:
                Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        A11yPreviewCard(state: state),
                        const SizedBox(height: DonySpacing.xl),

                        SettingsSectionHeader(l.a11ySectionText),
                        SettingsFlatGroup(
                          children: [
                            DonyListTile(
                              iconAsset: 'smartphone',
                              iconColor: cs.primary,
                              iconBgColor: cs.primaryContainer,
                              label: l.a11yFollowSystemLabel,
                              subtitle: l.a11yFollowSystemSubtitle,
                              trailing: Switch(
                                value: state.followSystemTextScale,
                                activeThumbColor: cs.primary,
                                onChanged: (v) =>
                                    bloc.add(FollowSystemTextScaleToggled(v)),
                              ),
                              onTap: () => bloc.add(
                                FollowSystemTextScaleToggled(
                                  !state.followSystemTextScale,
                                ),
                              ),
                            ),
                            A11ySliderRow(
                              value: state.textScaleFactor,
                              enabled: !state.followSystemTextScale,
                              onChanged: (v) =>
                                  bloc.add(TextScaleFactorChanged(v)),
                            ),
                            DonyListTile(
                              iconAsset: 'square-pen',
                              iconColor: cs.primary,
                              iconBgColor: cs.primaryContainer,
                              label: l.a11yBoldTextLabel,
                              subtitle: l.a11yBoldTextSubtitle,
                              showDivider: false,
                              trailing: Switch(
                                value: state.boldText,
                                activeThumbColor: cs.primary,
                                onChanged: (v) => bloc.add(BoldTextToggled(v)),
                              ),
                              onTap: () =>
                                  bloc.add(BoldTextToggled(!state.boldText)),
                            ),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.lg),

                        SettingsSectionHeader(l.a11ySectionDisplay),
                        SettingsFlatGroup(
                          children: [
                            A11yTristateRow(
                              iconAsset: 'contrast',
                              label: l.a11yHighContrastLabel,
                              subtitle: l.a11yHighContrastSubtitle,
                              sheetTitle: l.a11yHighContrastLabel,
                              value: state.highContrast,
                              onChanged: (v) =>
                                  bloc.add(HighContrastModeChanged(v)),
                            ),
                            DonyListTile(
                              iconAsset: 'link',
                              iconColor: cs.primary,
                              iconBgColor: cs.primaryContainer,
                              label: l.a11yUnderlineLinksLabel,
                              subtitle: l.a11yUnderlineLinksSubtitle,
                              trailing: Switch(
                                value: state.underlineLinks,
                                activeThumbColor: cs.primary,
                                onChanged: (v) =>
                                    bloc.add(UnderlineLinksToggled(v)),
                              ),
                              onTap: () => bloc.add(
                                UnderlineLinksToggled(!state.underlineLinks),
                              ),
                            ),
                            DonyListTile(
                              iconAsset: 'tag',
                              iconColor: cs.primary,
                              iconBgColor: cs.primaryContainer,
                              label: l.a11yReinforceLabelsLabel,
                              subtitle: l.a11yReinforceLabelsSubtitle,
                              showDivider: false,
                              trailing: Switch(
                                value: state.reinforceLabels,
                                activeThumbColor: cs.primary,
                                onChanged: (v) =>
                                    bloc.add(ReinforceLabelsToggled(v)),
                              ),
                              onTap: () => bloc.add(
                                ReinforceLabelsToggled(!state.reinforceLabels),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.lg),

                        SettingsSectionHeader(l.a11ySectionMotion),
                        SettingsFlatGroup(
                          children: [
                            A11yTristateRow(
                              iconAsset: 'circle-play',
                              label: l.a11yReduceMotionLabel,
                              subtitle: l.a11yReduceMotionSubtitle,
                              sheetTitle: l.a11yReduceMotionLabel,
                              value: state.reduceMotion,
                              showDivider: false,
                              onChanged: (v) =>
                                  bloc.add(ReduceMotionModeChanged(v)),
                            ),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.lg),

                        SettingsSectionHeader(l.a11ySectionMessagesActions),
                        SettingsFlatGroup(
                          children: [
                            DonyListTile(
                              iconAsset: 'messages-square',
                              iconColor: cs.primary,
                              iconBgColor: cs.primaryContainer,
                              label: l.a11yPersistentMessagesLabel,
                              subtitle: l.a11yPersistentMessagesSubtitle,
                              trailing: Switch(
                                value: state.persistentMessages,
                                activeThumbColor: cs.primary,
                                onChanged: (v) =>
                                    bloc.add(PersistentMessagesToggled(v)),
                              ),
                              onTap: () => bloc.add(
                                PersistentMessagesToggled(
                                  !state.persistentMessages,
                                ),
                              ),
                            ),
                            DonyListTile(
                              iconAsset: 'shield-check',
                              iconColor: cs.primary,
                              iconBgColor: cs.primaryContainer,
                              label: l.a11yConfirmActionsLabel,
                              subtitle: l.a11yConfirmActionsSubtitle,
                              showDivider: false,
                              trailing: Switch(
                                value: state.confirmImportantActions,
                                activeThumbColor: cs.primary,
                                onChanged: (v) =>
                                    bloc.add(ConfirmImportantActionsToggled(v)),
                              ),
                              onTap: () => bloc.add(
                                ConfirmImportantActionsToggled(
                                  !state.confirmImportantActions,
                                ),
                              ),
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
                              label: l.a11yOpenSystemSettingsLabel,
                              subtitle: l.a11yOpenSystemSettingsSubtitle,
                              showDivider: false,
                              trailing: Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                              onTap: () => AppSettings.openAppSettings(
                                type: AppSettingsType.accessibility,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.base),

                        Center(
                          child: TextButton(
                            onPressed: () => _confirmReset(context, bloc),
                            child: Text(
                              l.a11yResetAll,
                              style: tt.labelLarge?.copyWith(color: cs.error),
                            ),
                          ),
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
                    .slideY(
                      begin: 0.04,
                      duration: 280.ms,
                      curve: Curves.easeOutCubic,
                    ),
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    AccessibilityBloc bloc,
  ) async {
    final l = context.l10n;
    final ok = await DonyDialog.show(
      context,
      title: l.a11yResetAll,
      message: l.a11yResetAllMessage,
      variant: DonyDialogVariant.destructive,
    );
    if (ok ?? false) {
      bloc.add(const AccessibilityResetRequested());
    }
  }
}
