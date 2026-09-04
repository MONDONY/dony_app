import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/presentation/widgets/tool_key_presentation.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:flutter/material.dart';

/// Destination retenue dans la feuille de menu : l'événement à tracer et la
/// route à ouvrir.
///
/// La feuille ne navigue pas elle-même. Elle est montée sur le navigateur
/// racine (`DonyBottomSheet.show`), donc son contexte ne porte ni le
/// `GoRouter` du shell ni les blocs du hub : elle rend son choix à
/// l'appelant, qui trace puis pousse comme pour n'importe quelle tuile.
class ActivitesMenuChoice {
  const ActivitesMenuChoice(this.event, this.route);

  final String event;
  final String route;
}

/// Menu de l'onglet Activités, ouvert par le bouton burger de l'en-tête.
///
/// Ne reprend jamais les quatre tuiles « En ce moment » : elles sont juste
/// derrière la feuille, avec leurs compteurs et leur pastille de non-lus, et
/// deux chemins concurrents vers la même route ne rendent service à personne.
/// La feuille porte ce que l'écran ne montre pas (suivi, scan, paramètres,
/// portefeuille, aide) et les outils, qui vivent tout en bas du hub.
abstract final class ActivitesMenuSheet {
  static Future<ActivitesMenuChoice?> show(
    BuildContext context, {
    ToolsCompletionModel? tools,
  }) {
    return DonyBottomSheet.show<ActivitesMenuChoice>(
      context,
      child: _ActivitesMenuContent(tools: tools),
    );
  }
}

class _ActivitesMenuContent extends StatelessWidget {
  const _ActivitesMenuContent({this.tools});

  /// État de complétion déjà chargé par le hub. `null` tant qu'il n'a pas
  /// répondu : la feuille s'affiche alors sans pastilles plutôt que de
  /// relancer l'appel pour son propre compte.
  final ToolsCompletionModel? tools;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `IntrinsicHeight` est nécessaire : dans le scroll de la feuille,
        // `stretch` seul réclame une hauteur infinie et fait échouer le
        // layout. Sans lui, « Suivre un colis » passe sur deux lignes et
        // laisse « Paramètres » plus courte à côté.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _QuickAction(
                  key: const Key('menu-quick-track'),
                  iconAsset: 'search',
                  label: 'Suivre un colis',
                  color: cs.primary,
                  choice: const ActivitesMenuChoice(
                    AnalyticsEvents.activitesHubSearchOpened,
                    '/tracking/search',
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: _QuickAction(
                  key: const Key('menu-quick-scan'),
                  iconAsset: 'scan-line',
                  label: 'Scanner un colis',
                  color: cs.secondary,
                  choice: const ActivitesMenuChoice(
                    AnalyticsEvents.activitesHubScanOpened,
                    '/tracking/scan-hub',
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              const Expanded(
                child: _QuickAction(
                  key: Key('menu-quick-settings'),
                  iconAsset: 'sliders-horizontal',
                  label: 'Paramètres',
                  color: DonyColors.neutral600,
                  choice: ActivitesMenuChoice(
                    AnalyticsEvents.activitesHubSettingsOpened,
                    '/settings',
                  ),
                ),
              ),
            ],
          ),
        ),
        _SectionLabel(
          label: 'Mes outils',
          // « 3/5 prêts » : le même décompte que la carte « Publiez en 3 taps »
          // du hub, pour que le menu ne raconte pas une autre histoire.
          trailing: tools == null
              ? null
              : '${tools!.ready}/${tools!.total} prêts',
        ),
        _ToolTile(
          itemKey: const Key('menu-tool-alerts'),
          tool: ToolKey.alerts,
          iconAsset: 'bell',
          label: 'Mes alertes',
          color: cs.primary,
          event: AnalyticsEvents.activitesHubAlertsOpened,
          tools: tools,
        ),
        _ToolTile(
          itemKey: const Key('menu-tool-templates'),
          tool: ToolKey.tripTemplates,
          iconAsset: 'bookmark',
          label: 'Modèles de trajet',
          color: DonyColors.violet,
          event: AnalyticsEvents.activitesHubTemplatesOpened,
          tools: tools,
        ),
        _ToolTile(
          itemKey: const Key('menu-tool-price-grid'),
          tool: ToolKey.priceGrid,
          iconAsset: 'layout-grid',
          label: 'Ma grille de prix',
          color: cs.primary,
          event: AnalyticsEvents.activitesHubPriceGridOpened,
          tools: tools,
        ),
        _ToolTile(
          itemKey: const Key('menu-tool-addresses'),
          tool: ToolKey.addresses,
          iconAsset: 'map-pin',
          label: 'Mes adresses',
          color: cs.secondary,
          event: AnalyticsEvents.activitesHubAddressesOpened,
          tools: tools,
        ),
        _ToolTile(
          itemKey: const Key('menu-tool-recipients'),
          tool: ToolKey.recipients,
          iconAsset: 'contact',
          label: 'Mes destinataires',
          color: DonyColors.violet,
          event: AnalyticsEvents.activitesHubRecipientsOpened,
          tools: tools,
        ),
        // L'historique n'est pas un outil à préparer : jamais de pastille, et
        // il ne compte pas dans « x/5 prêts ».
        _MenuTile(
          itemKey: const Key('menu-item-history'),
          iconAsset: 'chart-line',
          label: 'Historique',
          color: cs.primary,
          choice: const ActivitesMenuChoice(
            AnalyticsEvents.activitesHubHistoryOpened,
            '/profile/shipments/history',
          ),
          showDivider: false,
        ),
        const _SectionLabel(label: 'Mon compte'),
        _MenuTile(
          itemKey: const Key('menu-item-wallet'),
          iconAsset: 'wallet',
          label: 'Portefeuille',
          color: cs.primary,
          choice: const ActivitesMenuChoice(
            AnalyticsEvents.activitesHubWalletOpened,
            '/payments/wallet',
          ),
        ),
        const _MenuTile(
          itemKey: Key('menu-item-help'),
          iconAsset: 'circle-help',
          label: 'Aide et support',
          color: DonyColors.amberDark,
          choice: ActivitesMenuChoice(
            AnalyticsEvents.activitesHubHelpOpened,
            '/profile/help/faq',
          ),
          showDivider: false,
        ),
      ],
    );
  }
}

// ── Actions rapides ──────────────────────────────────────────────────────────

/// Tuile carrée de la rangée du haut : pastille ronde, libellé sur deux lignes.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.color,
    required this.choice,
  });

  final String iconAsset;
  final String label;
  final Color color;
  final ActivitesMenuChoice choice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(choice),
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
  const _SectionLabel({required this.label, this.trailing});

  final String label;

  /// Compteur de complétion, affiché à droite du titre de section.
  final String? trailing;

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
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ligne de menu simple : icône teintée, libellé, chevron implicite.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.itemKey,
    required this.iconAsset,
    required this.label,
    required this.color,
    required this.choice,
    this.trailing,
    this.showDivider = true,
  });

  final Key itemKey;
  final String iconAsset;
  final String label;
  final Color color;
  final ActivitesMenuChoice choice;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return DonyListTile(
      key: itemKey,
      iconAsset: iconAsset,
      iconColor: color,
      label: label,
      trailing: trailing,
      showDivider: showDivider,
      onTap: () => Navigator.of(context).pop(choice),
    );
  }
}

/// Ligne d'un outil préparable : porte la pastille d'état des tuiles du hub.
class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.itemKey,
    required this.tool,
    required this.iconAsset,
    required this.label,
    required this.color,
    required this.event,
    required this.tools,
  });

  final Key itemKey;
  final ToolKey tool;
  final String iconAsset;
  final String label;
  final Color color;
  final String event;
  final ToolsCompletionModel? tools;

  @override
  Widget build(BuildContext context) {
    final model = tools;
    final Widget? badge;
    if (model == null) {
      badge = null;
    } else {
      final count = model.countOf(tool);
      final ready = count > 0;
      badge = ToolStatusBadge(
        ready: ready,
        label: ready ? tool.badgeLabel(count) : 'À configurer',
        semanticsLabel: ready
            ? '$label : ${tool.badgeLabel(count)}'
            : '$label : à configurer',
      );
    }

    return _MenuTile(
      itemKey: itemKey,
      iconAsset: iconAsset,
      label: label,
      color: color,
      trailing: badge,
      choice: ActivitesMenuChoice(event, tool.route),
    );
  }
}
