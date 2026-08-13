import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/data_export_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/delete_account_bottom_sheet.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DataSettingsScreen extends StatelessWidget {
  const DataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Mes données'),
      body: BlocListener<DataExportBloc, DataExportState>(
        listener: (context, state) {
          if (state is DataExportSuccess) {
            DonySnackbar.show(
              context,
              message:
                  'Export lancé. Tu recevras un e-mail avec le lien de téléchargement sous 72h.',
              type: DonySnackbarType.success,
            );
          } else if (state is DataExportError) {
            DonySnackbar.show(
              context,
              message: state.message,
              type: DonySnackbarType.error,
            );
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.lg,
            DonySpacing.lg,
            DonySpacing.huge,
          ),
          children: [
            const SettingsSectionHeader('VOS DONNÉES'),
            // Export tile — wrapped in BlocBuilder to react to loading state
            SettingsFlatGroup(
              children: [
                BlocBuilder<DataExportBloc, DataExportState>(
                  builder: (context, state) {
                    final isLoading = state is DataExportLoading;
                    return DonyListTile(
                      iconAsset: 'download',
                      iconColor: cs.primary,
                      iconBgColor: cs.primaryContainer,
                      label: 'Télécharger mes données',
                      subtitle: 'Export RGPD au format JSON',
                      showDivider: false,
                      trailing: isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            )
                          : null,
                      onTap: isLoading
                          ? null
                          : () => context.read<DataExportBloc>().add(
                              const DataExportRequested(),
                            ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.xl),
            const SettingsSectionHeader('DANGER ZONE'),
            SettingsFlatGroup(
              children: [
                DonyListTile(
                  iconAsset: 'trash',
                  iconColor: cs.error,
                  iconBgColor: cs.errorContainer,
                  label: 'Supprimer mon compte',
                  subtitle: 'Action irréversible',
                  showDivider: false,
                  destructive: true,
                  onTap: () => DeleteAccountBottomSheet.show(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
