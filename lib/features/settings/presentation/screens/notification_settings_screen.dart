import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Les réglages Hive s'affichent dès la construction du BLoC, mais c'est le
    // serveur qui filtre réellement les push : on le relit à l'ouverture pour
    // que l'écran montre ce qui est appliqué, et non un cache qui aurait pu
    // diverger (réinstallation, second appareil).
    final bloc = context.read<NotificationPrefsBloc>();
    bloc.add(const NotifPrefsSyncRequested());
    // La cloche « nouveaux colis compatibles » vit sur un autre endpoint : son
    // état n'est connu qu'après lecture.
    bloc.add(const NotifPackageMatchAlertLoadRequested());
  }

  void _toggle(BuildContext context, String key) {
    context.read<NotificationPrefsBloc>().add(NotifPrefToggled(key));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DonyAppBar(title: 'Notifications'),
      body: BlocBuilder<NotificationPrefsBloc, NotificationPrefsState>(
        builder: (context, state) {

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            children: [
              if (state.errorMessage != null) ...[
                _SyncErrorBanner(message: state.errorMessage!),
                const SizedBox(height: DonySpacing.lg),
              ],
              // ── Section 1 : Protections critiques ──────────────────────
              SettingsSectionHeader(
                'PROTECTIONS CRITIQUES',
                color: Theme.of(context).colorScheme.error,
              ),
              SettingsFlatGroup(
                children: [
                  _buildLockedTile(context,
                    iconAsset: 'badge-check',
                    label: 'Livraison confirmée',
                    subtitle: 'SMS automatique si push non reçu',
                  ),
                  _buildLockedTile(context,
                    iconAsset: 'banknote',
                    label: 'Paiement reçu',
                    subtitle: 'SMS automatique si push non reçu',
                  ),
                  _buildLockedTile(context,
                    iconAsset: 'gavel',
                    label: 'Litige ouvert',
                    subtitle: 'SMS automatique si push non reçu',
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              _buildCriticalBanner(context),
              const SizedBox(height: DonySpacing.xl),
              // ── Section 2 : Activité ────────────────────────────────────
              SettingsSectionHeader(
                'ACTIVITÉ',
                color: Theme.of(context).colorScheme.warning,
              ),
              SettingsFlatGroup(
                children: [
                  _buildTile(context,
                    label: 'Matchs & enchères',
                    subtitle: 'Demandes, acceptations, remise, annulation…',
                    key: 'push_activity_bids',
                    prefs: state.prefs,
                    onToggle: (key) => _toggle(context, key),
                  ),
                  // Cloche rapatriée de l'écran « Colis sur mes trajets »,
                  // supprimé avec sa route : le réglage reste, son écran non.
                  _buildPackageMatchTile(context, state.packageMatchAlert),
                  // Préférence serveur qui existait déjà et gouvernait les alertes
                  // corridor, sans qu'aucune tuile ne permette de l'atteindre.
                  _buildTile(context,
                    label: 'Nouveaux trajets',
                    subtitle: 'Alertes corridor et voyageurs suivis',
                    key: 'push_corridor_alerts',
                    prefs: state.prefs,
                    onToggle: (key) => _toggle(context, key),
                  ),
                  _buildTile(context,
                    label: 'Discussions de prix',
                    subtitle: 'Propositions, contre-offres, paiements…',
                    key: 'push_activity_negotiations',
                    prefs: state.prefs,
                    onToggle: (key) => _toggle(context, key),
                  ),
                  _buildTile(context,
                    label: 'Messages',
                    subtitle: 'Nouveaux messages reçus',
                    key: 'push_messages',
                    prefs: state.prefs,
                    onToggle: (key) => _toggle(context, key),
                  ),
                  // Trois lignes retirées ici, toutes sans effet possible :
                  //
                  // « Rappel trajet J-1 » ne gouvernait rien. Aucun scheduler J-1 n'existe
                  // côté serveur ; la préférence ne filtrait en réalité que « Bon voyage ! »,
                  // désormais in-app, donc plus jamais soumis à une préférence de push.
                  //
                  // « Actus dony » (Push et E-mail) n'a aucun émetteur : aucun code n'envoie
                  // de notification de type PROMO, et `email_promo` n'a même pas de champ
                  // correspondant côté serveur. La préférence `pushPromo` reste en base et
                  // dans le contrat, à `false` par défaut : le jour où des actus existeront,
                  // la ligne reviendra sans que personne ait été abonné à son insu.
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

  Widget _buildLockedTile(
    BuildContext context, {
    required String iconAsset,
    required String label,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return DonyListTile(
      iconAsset: iconAsset,
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
          DonyIcon('info', size: 16, color: cs.error),
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

  /// Ligne « Nouveaux colis compatibles » : réglage serveur, donc pas de clé
  /// dans la map Hive. Tant que la valeur est inconnue ([enabled] null), la
  /// ligne est désactivée plutôt que d'afficher un état inventé.
  DonyListTile _buildPackageMatchTile(BuildContext context, bool? enabled) {
    final cs = Theme.of(context).colorScheme;
    final isOn = enabled ?? false;
    final isKnown = enabled != null;

    return DonyListTile(
      iconAsset: isOn ? 'bell' : 'bell-off',
      iconColor: isOn ? cs.primary : cs.onSurfaceVariant,
      iconBgColor: isOn
          ? cs.primaryContainer
          : cs.onSurfaceVariant.withValues(alpha: 0.12),
      label: 'Nouveaux colis compatibles',
      subtitle: 'Quand un colis correspond à un de tes trajets',
      enabled: isKnown,
      trailing: IgnorePointer(
        child: Switch(value: isOn, onChanged: isKnown ? (_) {} : null),
      ),
      onTap: () => context
          .read<NotificationPrefsBloc>()
          .add(NotifPackageMatchAlertToggled(!isOn)),
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
      iconAsset: isOn ? 'bell' : 'bell-off',
      iconColor: isOn ? cs.primary : cs.onSurfaceVariant,
      iconBgColor: isOn
          ? cs.primaryContainer
          : cs.onSurfaceVariant.withValues(alpha: 0.12),
      label: label,
      subtitle: subtitle,
      trailing: IgnorePointer(
        child: Switch(value: isOn, onChanged: (_) {}),
      ),
      onTap: () => onToggle(key),
    );
  }
}

/// Affiché quand le serveur a refusé une bascule : celle-ci a été annulée, donc
/// l'interrupteur au-dessus montre bien l'état réellement appliqué.
class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        children: [
          DonyIcon('wifi-off', color: cs.onErrorContainer, size: 18),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
