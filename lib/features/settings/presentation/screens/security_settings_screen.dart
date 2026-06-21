import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/pin_confirm_bottom_sheet.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({
    super.key,
    @visibleForTesting this.biometricAvailableOverride,
  });

  /// Override for tests only — bypasses the real [LocalAuthentication] check.
  final bool? biometricAvailableOverride;

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  late final Future<bool> _biometricFuture;

  @override
  void initState() {
    super.initState();
    if (widget.biometricAvailableOverride != null) {
      _biometricFuture = Future.value(widget.biometricAvailableOverride);
    } else {
      final auth = LocalAuthentication();
      _biometricFuture = Future.wait([
        auth.canCheckBiometrics,
        auth.isDeviceSupported(),
      ]).then((r) => r[0] || r[1]);
    }
  }

  /// Shows PIN confirmation when the toggle is currently ON (disabling).
  /// Dispatches the [event] directly when the toggle is currently OFF (enabling).
  Future<void> _toggleWithPinGuard(
    BuildContext context, {
    required bool currentlyEnabled,
    required AppPreferencesEvent event,
  }) async {
    if (currentlyEnabled) {
      // Désactivation → confirmation PIN requise
      final confirmed = await PinConfirmBottomSheet.show(
        context,
        authService: getIt<LocalAuthService>(),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
    }
    if (context.mounted) {
      context.read<AppPreferencesBloc>().add(event);
    }
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
                  const SettingsSectionHeader('PAIEMENTS'),
                  SettingsFlatGroup(children: [
                    DonyListTile(
                      iconAsset: 'fingerprint',
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
                            ? (_) => _toggleWithPinGuard(
                                  context,
                                  currentlyEnabled:
                                      prefsState.preferences.biometricEnabled,
                                  event: const BiometricToggled(),
                                )
                            : null,
                      ),
                      showDivider: false,
                      onTap: biometricAvailable
                          ? () => _toggleWithPinGuard(
                                context,
                                currentlyEnabled:
                                    prefsState.preferences.biometricEnabled,
                                event: const BiometricToggled(),
                              )
                          : null,
                    ),
                  ]),
                  const SizedBox(height: DonySpacing.lg),
                  const SettingsSectionHeader('APPLICATION'),
                  SettingsFlatGroup(children: [
                    DonyListTile(
                      iconAsset: 'lock',
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
                            ? (_) => _toggleWithPinGuard(
                                  context,
                                  currentlyEnabled: prefsState
                                      .preferences.appLockBiometricEnabled,
                                  event: const AppLockBiometricToggled(),
                                )
                            : null,
                      ),
                      showDivider: false,
                      onTap: biometricAvailable
                          ? () => _toggleWithPinGuard(
                                context,
                                currentlyEnabled: prefsState
                                    .preferences.appLockBiometricEnabled,
                                event: const AppLockBiometricToggled(),
                              )
                          : null,
                    ),
                  ]),
                  const SizedBox(height: DonySpacing.lg),
                  const SettingsSectionHeader('AUTHENTIFICATION'),
                  SettingsFlatGroup(children: [
                    DonyListTile(
                      iconAsset: 'key-round',
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
                  const SettingsSectionHeader('SESSION'),
                  SettingsFlatGroup(children: [
                    DonyListTile(
                      iconAsset: 'smartphone',
                      iconColor: cs.primary,
                      iconBgColor: cs.primaryContainer,
                      label: 'Appareils connectés',
                      subtitle: 'Voir et révoquer les sessions actives',
                      showDivider: false,
                      onTap: () => context.push(
                        '/settings/security/devices',
                      ),
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
}
