import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      _checkBiometric(),
    );
  }

  Future<void> _checkBiometric() async {
    final available = await _localAuth.canCheckBiometrics;
    if (mounted) {
      setState(() => _biometricAvailable = available);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Sécurité'),
      body: BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
        builder: (context, prefsState) {
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
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Biométrie avant paiement',
                  subtitle: _biometricAvailable
                      ? 'Empreinte digitale ou Face ID'
                      : 'Non disponible sur cet appareil',
                  trailing: Switch(
                    value: _biometricAvailable,
                    activeThumbColor: cs.primary,
                    onChanged: _biometricAvailable ? (_) {} : null,
                  ),
                  showDivider: false,
                  onTap: _biometricAvailable ? () {} : null,
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
