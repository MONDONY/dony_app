import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  late final Future<bool> _biometricFuture;

  @override
  void initState() {
    super.initState();
    final auth = LocalAuthentication();
    _biometricFuture = Future.wait([
      auth.canCheckBiometrics,
      auth.isDeviceSupported(),
    ]).then((r) => r[0] || r[1]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Sécurité'),
      body: FutureBuilder<bool>(
        future: _biometricFuture,
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
                  const _SectionLabel('APPLICATION'),
                  DonyListSection(tiles: [
                    DonyListTile(
                      icon: Icons.lock_rounded,
                      iconColor: biometricAvailable
                          ? cs.primary
                          : cs.onSurfaceVariant,
                      iconBgColor: biometricAvailable
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      label: "Verrouillage de l'app",
                      subtitle: biometricAvailable
                          ? "Biométrie ou Face ID à l'ouverture"
                          : 'Non disponible sur cet appareil',
                      trailing: Switch(
                        value: biometricAvailable &&
                            prefsState.preferences.appLockBiometricEnabled,
                        activeThumbColor: cs.primary,
                        onChanged: biometricAvailable
                            ? (_) => context
                                .read<AppPreferencesBloc>()
                                .add(const AppLockBiometricToggled())
                            : null,
                      ),
                      showDivider: false,
                      onTap: biometricAvailable
                          ? () => context
                              .read<AppPreferencesBloc>()
                              .add(const AppLockBiometricToggled())
                          : null,
                    ),
                  ]),
                  const SizedBox(height: DonySpacing.lg),
                  const _SectionLabel('AUTHENTIFICATION'),
                  DonyListSection(tiles: [
                    DonyListTile(
                      icon: Icons.pin_rounded,
                      iconColor: cs.primary,
                      iconBgColor: cs.primaryContainer,
                      label: 'Modifier le code PIN',
                      subtitle: 'Code à 6 chiffres',
                      showDivider: false,
                      onTap: () async {
                        await context.push<bool>(
                          '/settings/security/change-pin',
                        );
                      },
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
