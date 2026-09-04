import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Action retenue dans la feuille de menu de l'onglet Moi.
///
/// La feuille ne fait rien elle-même. Elle est montée sur le navigateur
/// racine (`DonyBottomSheet.show`), donc son contexte ne porte ni le
/// `GoRouter` du shell ni les blocs de l'écran : elle rend son choix à
/// l'appelant, qui trace, pousse une route ou ouvre le dialogue qui convient.
/// Toutes ces entrées ne sont pas des routes (déconnexion, suppression), d'où
/// une énumération plutôt qu'un couple événement/route comme sur Activités.
enum ProfileMenuAction {
  editProfile,
  settings,
  exportData,
  logout,
  deleteAccount,
}

/// Menu de l'onglet Moi, ouvert par le bouton burger de l'en-tête.
///
/// Jumelle de la feuille Activités : une rangée de raccourcis en haut, une
/// liste dessous. Elle porte le compte lui-même, ce que l'écran ne montre
/// plus : modifier le profil, les paramètres, l'export des données, la
/// déconnexion et la suppression. Elle ne redit aucune tuile de la page.
abstract final class ProfileMenuSheet {
  static Future<ProfileMenuAction?> show(
    BuildContext context, {
    required bool canDeleteAccount,
  }) {
    return DonyBottomSheet.show<ProfileMenuAction>(
      context,
      child: _ProfileMenuContent(canDeleteAccount: canDeleteAccount),
    );
  }
}

class _ProfileMenuContent extends StatelessWidget {
  const _ProfileMenuContent({required this.canDeleteAccount});

  /// `false` quand une suppression est déjà demandée : la bannière de l'écran
  /// propose la réactivation, redemander la suppression n'aurait pas de sens.
  final bool canDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `IntrinsicHeight` est nécessaire : dans le scroll de la feuille,
        // `stretch` seul réclame une hauteur infinie et fait échouer le
        // layout (voir la feuille Activités).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _QuickAction(
                  key: const Key('profile-menu-edit'),
                  iconAsset: 'square-pen',
                  label: 'Modifier le profil',
                  color: cs.primary,
                  action: ProfileMenuAction.editProfile,
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              const Expanded(
                child: _QuickAction(
                  key: Key('profile-menu-settings'),
                  iconAsset: 'sliders-horizontal',
                  label: 'Paramètres',
                  color: DonyColors.neutral600,
                  action: ProfileMenuAction.settings,
                ),
              ),
            ],
          ),
        ),
        const _SectionLabel(label: 'Mon compte'),
        _MenuTile(
          itemKey: const Key('profile-menu-export'),
          iconAsset: 'download',
          label: 'Télécharger mes données',
          subtitle: 'Export RGPD au format JSON',
          color: cs.primary,
          action: ProfileMenuAction.exportData,
        ),
        _MenuTile(
          itemKey: const Key('profile-menu-logout'),
          iconAsset: 'log-out',
          label: 'Se déconnecter',
          color: DonyColors.neutral600,
          action: ProfileMenuAction.logout,
          showDivider: canDeleteAccount,
        ),
        if (canDeleteAccount)
          _MenuTile(
            itemKey: const Key('profile-menu-delete'),
            iconAsset: 'trash',
            label: 'Supprimer mon compte',
            subtitle: 'Délai de rétractation de 30 jours',
            color: cs.error,
            action: ProfileMenuAction.deleteAccount,
            destructive: true,
            showDivider: false,
          ),
      ],
    );
  }
}

// ── Raccourcis du haut ───────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.color,
    required this.action,
  });

  final String iconAsset;
  final String label;
  final Color color;
  final ProfileMenuAction action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(action),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.sm,
            vertical: DonySpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: DonyIcon(
                    iconAsset,
                    size: 20,
                    color: DonyColors.neutral0,
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: tt.labelLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Lignes ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.xs,
        DonySpacing.lg,
        DonySpacing.xs,
        DonySpacing.xs,
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.itemKey,
    required this.iconAsset,
    required this.label,
    required this.color,
    required this.action,
    this.subtitle,
    this.destructive = false,
    this.showDivider = true,
  });

  final Key itemKey;
  final String iconAsset;
  final String label;
  final String? subtitle;
  final Color color;
  final ProfileMenuAction action;
  final bool destructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return DonyListTile(
      key: itemKey,
      iconAsset: iconAsset,
      iconColor: color,
      // Le fond suit la teinte de l'icône, comme sur la feuille Activités :
      // le bleu par défaut détonnait sous une icône rouge ou grise.
      iconBgColor: color.withValues(alpha: 0.12),
      label: label,
      subtitle: subtitle,
      destructive: destructive,
      showDivider: showDivider,
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
