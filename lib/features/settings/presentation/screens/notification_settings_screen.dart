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
                title: 'PROTECTIONS CRITIQUES',
                titleColor: Theme.of(context).colorScheme.error,
                tiles: [
                  _buildLockedTile(
                    context,
                    icon: Icons.verified_rounded,
                    label: 'Livraison confirmée',
                    subtitle: 'SMS automatique si push non reçu',
                  ),
                  _buildLockedTile(
                    context,
                    icon: Icons.payments_rounded,
                    label: 'Paiement reçu',
                    subtitle: 'SMS automatique si push non reçu',
                  ),
                  _buildLockedTile(
                    context,
                    icon: Icons.gavel_rounded,
                    label: 'Litige ouvert',
                    subtitle: 'SMS automatique si push non reçu',
                  ),
                ],
                footer: _buildInfoBanner(context),
              ),
              const SizedBox(height: DonySpacing.xl),
              _buildSection(
                context,
                title: 'ACTIVITÉ',
                titleColor: Theme.of(context).colorScheme.tertiary,
                tiles: [
                  _buildTile(
                    context,
                    icon: Icons.handshake_rounded,
                    label: 'Matchs & enchères',
                    subtitle: 'Demandes, acceptations, remise, annulation…',
                    key: 'push_activity_bids',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(
                    context,
                    icon: Icons.forum_rounded,
                    label: 'Négociations',
                    subtitle: 'Propositions, contre-offres, paiements…',
                    key: 'push_activity_negotiations',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(
                    context,
                    icon: Icons.chat_bubble_rounded,
                    label: 'Messages',
                    subtitle: 'Nouveaux messages reçus',
                    key: 'push_messages',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(
                    context,
                    icon: Icons.calendar_today_rounded,
                    label: 'Rappel trajet J-1',
                    subtitle: 'La veille de chaque trajet',
                    key: 'push_trip_reminder',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),
              _buildSection(
                context,
                title: 'ACTUS & PROMOTIONS',
                titleColor: Theme.of(context).colorScheme.onSurfaceVariant,
                tiles: [
                  _buildTile(
                    context,
                    icon: Icons.campaign_rounded,
                    label: 'Actus dony (Push)',
                    key: 'push_promo',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(
                    context,
                    icon: Icons.email_rounded,
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
    required List<Widget> tiles,
    Color? titleColor,
    Widget? footer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: DonySpacing.xs,
            bottom: DonySpacing.sm,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: titleColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1)
                  Divider(
                    height: 1,
                    indent: DonySpacing.lg,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: DonySpacing.sm),
          footer,
        ],
      ],
    );
  }

  Widget _buildLockedTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.errorContainer.withValues(alpha: 0.08),
      child: DonyListTile(
        icon: icon,
        iconColor: cs.error,
        iconBgColor: cs.errorContainer.withValues(alpha: 0.3),
        label: label,
        subtitle: subtitle,
        trailing: _LockedBadge(cs: cs),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String key,
    required Map<String, bool> prefs,
    required void Function(String) onToggle,
    String? subtitle,
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
      subtitle: subtitle,
      trailing: Switch(
        value: isOn,
        onChanged: (_) => onToggle(key),
      ),
      onTap: () => onToggle(key),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.errorContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: cs.error,
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Ces notifications protègent vos transactions. Elles ne peuvent pas être désactivées.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  final ColorScheme cs;
  const _LockedBadge({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Toujours actif',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
