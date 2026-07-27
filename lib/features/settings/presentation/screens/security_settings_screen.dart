import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/bloc/pin_status_cubit.dart';
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
  ///
  /// [pinConfigured] faux : aucun code à vérifier, donc aucune confirmation.
  /// Sans cette sortie, désactiver un réglage deviendrait impossible pour qui
  /// n'a pas de PIN, la feuille de confirmation n'ayant rien à comparer.
  Future<void> _toggleWithPinGuard(
    BuildContext context, {
    required bool currentlyEnabled,
    required AppPreferencesEvent event,
    required bool pinConfigured,
  }) async {
    if (currentlyEnabled && pinConfigured) {
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

  /// Active le verrouillage : envoie créer un PIN, puis relit l'état réel.
  Future<void> _enablePin(BuildContext context) async {
    final cubit = context.read<PinStatusCubit>();
    await context.push<bool>('/settings/security/create-pin');
    await cubit.refresh();
  }

  /// Désactive le verrouillage, code actuel exigé : sans cette confirmation,
  /// un téléphone déverrouillé laissé sans surveillance suffirait à retirer la
  /// protection.
  Future<void> _disablePin(BuildContext context) async {
    final cubit = context.read<PinStatusCubit>();
    final confirmed = await PinConfirmBottomSheet.show(
      context,
      authService: getIt<LocalAuthService>(),
    );
    if (confirmed != true) {
      return;
    }
    await cubit.disable();
    if (context.mounted) {
      DonySnackbar.show(
        context,
        message: "Code PIN retiré, l'app s'ouvrira sans code",
        type: DonySnackbarType.info,
      );
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
              final pinState = context.watch<PinStatusCubit>().state;
              // Nul pendant la lecture du secure storage : on affiche le défaut
              // d'un compte neuf, code PIN désactivé.
              final pinConfigured = pinState.configured ?? false;

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
                                  pinConfigured: pinConfigured,
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
                                pinConfigured: pinConfigured,
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
                      // Sans code PIN il n'y a aucun verrouillage à
                      // l'ouverture : la biométrie ne fait que remplacer la
                      // saisie du code. Le dire, plutôt que de laisser croire
                      // que l'app est protégée.
                      subtitle: !biometricAvailable
                          ? 'Non disponible sur cet appareil'
                          : pinConfigured
                              ? "Biométrie ou Face ID à l'ouverture"
                              : "Nécessite d'activer le code PIN ci-dessous",
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
                                  pinConfigured: pinConfigured,
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
                                pinConfigured: pinConfigured,
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
                      label: "Code PIN à l'ouverture",
                      subtitle: pinConfigured
                          ? 'Demandé à chaque ouverture de yadony'
                          : "Désactivé, l'app s'ouvre sans code",
                      trailing: Switch(
                        value: pinConfigured,
                        activeThumbColor: cs.primary,
                        onChanged: pinState.isBusy
                            ? null
                            : (v) => v
                                ? _enablePin(context)
                                : _disablePin(context),
                      ),
                      showDivider: pinConfigured,
                      onTap: pinState.isBusy
                          ? null
                          : () => pinConfigured
                              ? _disablePin(context)
                              : _enablePin(context),
                    ),
                    // Rien à modifier tant qu'aucun code n'existe : la création
                    // passe par l'interrupteur ci-dessus.
                    if (pinConfigured)
                      DonyListTile(
                        iconAsset: 'shield-check',
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
