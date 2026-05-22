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
              // ── Section 1 : Protections critiques ──────────────────────
              _buildSectionHeader(context,
                  title: 'PROTECTIONS CRITIQUES',
                  titleColor: Theme.of(context).colorScheme.error),
              _buildLockedTile(context,
                icon: Icons.verified_rounded,
                label: 'Livraison confirmée',
                subtitle: 'SMS automatique si push non reçu',
              ),
              _buildLockedTile(context,
                icon: Icons.payments_rounded,
                label: 'Paiement reçu',
                subtitle: 'SMS automatique si push non reçu',
              ),
              _buildLockedTile(context,
                icon: Icons.gavel_rounded,
                label: 'Litige ouvert',
                subtitle: 'SMS automatique si push non reçu',
              ),
              const SizedBox(height: DonySpacing.sm),
              _buildCriticalBanner(context),
              const SizedBox(height: DonySpacing.xl),
              // ── Section 2 : Activité ────────────────────────────────────
              _buildSectionHeader(context,
                  title: 'ACTIVITÉ',
                  titleColor: const Color(0xFFD97706)),
              DonyListSection(
                title: '',
                tiles: [
                  _buildTile(context,
                    label: 'Matchs & enchères',
                    subtitle: 'Demandes, acceptations, remise, annulation…',
                    key: 'push_activity_bids',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Négociations',
                    subtitle: 'Propositions, contre-offres, paiements…',
                    key: 'push_activity_negotiations',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Messages',
                    subtitle: 'Nouveaux messages reçus',
                    key: 'push_messages',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Rappel trajet J-1',
                    subtitle: 'La veille de chaque trajet',
                    key: 'push_trip_reminder',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),
              // ── Section 3 : Actus & promotions ─────────────────────────
              _buildSectionHeader(context,
                  title: 'ACTUS & PROMOTIONS',
                  titleColor: Theme.of(context).colorScheme.onSurfaceVariant),
              DonyListSection(
                title: '',
                tiles: [
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

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: titleColor ??
                  Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
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
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      margin: const EdgeInsets.only(bottom: 4),
      child: DonyListTile(
        icon: icon,
        iconColor: cs.error,
        iconBgColor: cs.errorContainer,
        label: label,
        subtitle: subtitle,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Toujours actif',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.errorContainer.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: cs.error),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Ces notifications protègent vos transactions. '
              'Elles ne peuvent pas être désactivées.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  DonyListTile _buildTile(
    BuildContext context, {
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
      trailing: Switch(value: isOn, onChanged: (_) => onToggle(key)),
      onTap: () => onToggle(key),
    );
  }
}
