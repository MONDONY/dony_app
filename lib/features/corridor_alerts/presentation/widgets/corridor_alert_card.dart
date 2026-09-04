import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte d'une alerte corridor : icône de direction, corridor, filtres en
/// chips et une ligne d'état qui dit ce qui s'est passé (nouveautés, rien de
/// neuf, expirée, en pause). Les actions secondaires vivent derrière le menu
/// « ⋯ » ; la carte entière ouvre les correspondances.
class CorridorAlertCard extends StatelessWidget {
  const CorridorAlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    required this.onMenu,
    required this.onResume,
    required this.onExtend,
    this.now,
  });

  final CorridorAlertModel alert;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  /// « Reprendre » sur une alerte en pause.
  final VoidCallback onResume;

  /// « Prolonger » sur une alerte dont la fenêtre de dates est passée.
  final VoidCallback onExtend;

  /// Horloge injectable pour les tests ; `DateTime.now()` sinon.
  final DateTime? now;

  static String _d(DateTime d) => DateFormat('d MMM', 'fr').format(d);

  /// « 15 au 30 sept », « À partir du 15 sept », « Jusqu'au 30 sept » ou
  /// « Toute date ».
  static String dateLabel(CorridorAlertModel a) {
    final from = a.dateFrom;
    final to = a.dateTo;
    if (from != null && to != null) {
      final sameMonth = from.year == to.year && from.month == to.month;
      return sameMonth
          ? '${from.day} au ${_d(to)}'
          : '${_d(from)} au ${_d(to)}';
    }
    if (from != null) return 'À partir du ${_d(from)}';
    if (to != null) return 'Jusqu\'au ${_d(to)}';
    return 'Toute date';
  }

  /// « ≥ 3 kg » ou « Tout poids » (alertes colis uniquement).
  static String weightLabel(CorridorAlertModel a) {
    final kg = a.minWeightKg;
    if (kg == null) return 'Tout poids';
    final display = kg == kg.truncateToDouble() ? '${kg.toInt()} kg' : '$kg kg';
    return '≥ $display';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTrips = alert.direction == AlertDirection.senderWantsTrips;
    final paused = !alert.active;
    final expired = !paused && alert.isExpiredAt(now ?? DateTime.now());

    final (iconAsset, iconBg, iconFg) = isTrips
        ? ('plane', cs.primaryContainer, cs.primary)
        : ('package', cs.secondaryContainer, cs.secondary);

    final chips = <Widget>[
      _FilterChip(iconAsset: 'calendar', label: dateLabel(alert)),
      if (isTrips && alert.hasPickupZone)
        _FilterChip(
          iconAsset: 'map-pin',
          label: alert.centerLabel != null
              ? '≤ ${alert.radiusKm} km · ${alert.centerLabel}'
              : '≤ ${alert.radiusKm} km',
          background: cs.primaryContainer,
          foreground: cs.onPrimaryContainer,
        ),
      if (!isTrips) _FilterChip(iconAsset: 'weight', label: weightLabel(alert)),
      if (!isTrips)
        for (final c in alert.contentCategories) _FilterChip(label: c),
    ];

    final card = DonyCard(
      key: Key('alert-card-${alert.id}'),
      elevated: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIconContainer(
                iconAsset: iconAsset,
                backgroundColor: iconBg,
                iconColor: iconFg,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  alert.corridorLabel,
                  style: tt.titleLarge?.copyWith(
                    color: paused ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: Key('alert-card-menu-${alert.id}'),
                tooltip: 'Options',
                visualDensity: VisualDensity.compact,
                icon: DonyIcon(
                  'ellipsis-vertical',
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: onMenu,
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          Wrap(
            spacing: DonySpacing.xs + 2,
            runSpacing: DonySpacing.xs + 2,
            children: chips,
          ),
          const SizedBox(height: DonySpacing.md),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: DonySpacing.sm + 2),
          _StatusRow(
            alert: alert,
            isTrips: isTrips,
            paused: paused,
            expired: expired,
            onTap: onTap,
            onResume: onResume,
            onExtend: onExtend,
          ),
        ],
      ),
    );

    // En pause : la carte s'efface sans disparaître, le menu reste actif.
    return paused ? Opacity(opacity: 0.6, child: card) : card;
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.alert,
    required this.isTrips,
    required this.paused,
    required this.expired,
    required this.onTap,
    required this.onResume,
    required this.onExtend,
  });

  final CorridorAlertModel alert;
  final bool isTrips;
  final bool paused;
  final bool expired;
  final VoidCallback onTap;
  final VoidCallback onResume;
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final noun = isTrips ? 'trajet' : 'colis';
    String plural(int n) => isTrips && n > 1 ? '${noun}s' : noun;

    if (paused) {
      return Row(
        children: [
          DonyIcon('bell-off', size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'En pause · aucune notification',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          _InlineAction(label: 'Reprendre', onPressed: onResume),
        ],
      );
    }

    if (expired) {
      return Row(
        children: [
          DonyIcon('clock', size: 14, color: cs.warning),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Expirée le ${CorridorAlertCard._d(alert.dateTo!)}',
              style: tt.bodySmall?.copyWith(
                color: cs.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _InlineAction(
            label: 'Prolonger',
            iconAsset: 'refresh-cw',
            onPressed: onExtend,
          ),
        ],
      );
    }

    if (alert.hasNews) {
      final n = alert.newMatchCount;
      final label = '$n nouveau${n > 1 ? 'x' : ''} ${plural(n)}';
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: DonyColors.amberDark,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              label,
              key: const Key('alert-card-news'),
              style: tt.bodySmall?.copyWith(
                color: DonyColors.amberDark,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _InlineAction(
            label: 'Voir',
            iconAsset: 'arrow-right',
            onPressed: onTap,
          ),
        ],
      );
    }

    final total = alert.matchCount;
    final quiet = total == 0
        ? 'Aucun $noun pour l\'instant'
        : 'Rien de neuf · $total ${plural(total)} au total';
    return Row(
      children: [
        Expanded(
          child: Text(
            quiet,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        DonyIcon(
          'chevron-right',
          size: 16,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}

/// Lien d'action en fin de ligne d'état : visuel fin, zone tappable de 44 px.
class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.label,
    required this.onPressed,
    this.iconAsset,
  });

  final String label;
  final String? iconAsset;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        minimumSize: const Size(kDonyMinTapTarget, kDonyMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (iconAsset != null) ...[
            const SizedBox(width: DonySpacing.xs),
            DonyIcon(iconAsset!, size: 14, color: cs.primary),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.iconAsset,
    this.background,
    this.foreground,
  });

  final String label;
  final String? iconAsset;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = foreground ?? cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: background ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset != null) ...[
            DonyIcon(iconAsset!, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: fg,
              letterSpacing: 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
