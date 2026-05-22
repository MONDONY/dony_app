import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Sécurité'),
      body: FutureBuilder<bool>(
        future: LocalAuthentication().canCheckBiometrics,
        builder: (context, snapshot) {
          final biometricAvailable = snapshot.data ?? false;

          return BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
            builder: (context, prefsState) {
              final biometricEnabled =
                  prefsState.preferences.biometricEnabled && biometricAvailable;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.huge,
                ),
                children: [
                  const _SectionLabel('PAIEMENTS'),
                  DonyListSection(tiles: [
                    DonyListTile(
                      icon: Icons.fingerprint_rounded,
                      iconColor: biometricAvailable
                          ? cs.primary
                          : cs.onSurfaceVariant,
                      iconBgColor: biometricAvailable
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      label: 'Biométrie avant paiement',
                      subtitle: biometricAvailable
                          ? 'Empreinte digitale ou Face ID'
                          : 'Non disponible sur cet appareil',
                      trailing: Switch(
                        value: biometricEnabled,
                        activeThumbColor: cs.primary,
                        onChanged: biometricAvailable
                            ? (_) => context
                                .read<AppPreferencesBloc>()
                                .add(const BiometricToggled())
                            : null,
                      ),
                      showDivider: false,
                      onTap: biometricAvailable
                          ? () => context
                              .read<AppPreferencesBloc>()
                              .add(const BiometricToggled())
                          : null,
                    ),
                  ]),
                  const SizedBox(height: DonySpacing.lg),
                  const _SectionLabel('SESSION'),
                  DonyListSection(tiles: [
                    DonyListTile(
                      icon: Icons.devices_rounded,
                      iconColor: cs.onSurfaceVariant,
                      iconBgColor: cs.surfaceContainerHighest,
                      label: 'Appareils connectés',
                      subtitle: 'Voir et révoquer les sessions actives',
                      showDivider: false,
                      onTap: () => _showRevokeDialog(context, cs),
                    ),
                  ]),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showRevokeDialog(BuildContext context, ColorScheme cs) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Déconnecter tous les appareils ?'),
        content: const Text(
          'Tu seras déconnecté de tous tes appareils et devras te reconnecter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fonctionnalité disponible prochainement'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Déconnecter'),
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
