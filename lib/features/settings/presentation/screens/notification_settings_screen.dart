import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DonyAppBar(title: 'Notifications'),
      body: BlocBuilder<NotificationPrefsBloc, NotificationPrefsState>(
        builder: (context, state) {
          void toggle(String key) =>
              context.read<NotificationPrefsBloc>().add(NotifPrefToggled(key));

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            children: [
              _buildSection(
                context,
                title: 'Paiements',
                tiles: [
                  _buildTile(context,
                    label: 'Paiement reçu (Push)',
                    key: 'push_payment',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Paiement reçu (SMS)',
                    key: 'sms_payment',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),
              _buildSection(
                context,
                title: 'Livraisons',
                tiles: [
                  _buildTile(context,
                    label: 'Colis remis (Push)',
                    key: 'push_delivery',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Colis remis (SMS)',
                    key: 'sms_delivery',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),
              _buildSection(
                context,
                title: 'Matchs & Négociations',
                tiles: [
                  _buildTile(context,
                    label: 'Nouveau match / offre (Push)',
                    key: 'push_match',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),
              _buildSection(
                context,
                title: 'Litiges',
                tiles: [
                  _buildTile(context,
                    label: 'Litige ouvert (Push)',
                    key: 'push_dispute',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Litige ouvert (SMS)',
                    key: 'sms_dispute',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Litige ouvert (E-mail)',
                    key: 'email_dispute',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),
              _buildSection(
                context,
                title: 'Rappels & Promotions',
                tiles: [
                  _buildTile(context,
                    label: 'Rappel trajet J-1 (Push)',
                    key: 'push_trip_reminder',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Actus dony (Push)',
                    key: 'push_promo',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Actus dony (E-mail)',
                    key: 'email_promo',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                ],
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
              .slideY(begin: 0.04, duration: 280.ms, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<DonyListTile> tiles,
  }) {
    return DonyListSection(title: title, tiles: tiles);
  }

  DonyListTile _buildTile(
    BuildContext context, {
    required String label,
    required String key,
    required Map<String, bool> prefs,
    required void Function(String) onToggle,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isOn = prefs[key] ?? false;

    return DonyListTile(
      icon: isOn
          ? Icons.notifications_active_rounded
          : Icons.notifications_off_outlined,
      iconColor: isOn ? cs.primary : cs.onSurfaceVariant,
      iconBgColor: isOn
          ? cs.primaryContainer
          : cs.onSurfaceVariant.withValues(alpha: 0.12),
      label: label,
      trailing: Switch(
        value: isOn,
        onChanged: (_) => onToggle(key),
      ),
      onTap: () => onToggle(key),
    );
  }
}
