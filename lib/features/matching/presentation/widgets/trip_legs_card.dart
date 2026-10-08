import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// « Étape 1/2 du voyage » sur la fiche d'une étape (FLUTTER-4D), avec les
/// autres étapes du voyage, ouvrables au tap.
///
/// Lit un [TripGroupCubit] fourni plus haut. Rien n'est affiché pour un
/// trajet isolé, pendant le chargement ou en cas d'échec : la fiche reste
/// celle d'un trajet ordinaire.
class TripLegsCard extends StatelessWidget {
  const TripLegsCard({
    super.key,
    required this.announcementId,
    required this.onOpenLeg,
    this.padding = EdgeInsets.zero,
  });

  final String announcementId;
  final ValueChanged<TripLegSummary> onOpenLeg;

  /// Marge autour de la carte, appliquée seulement quand elle s'affiche.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Sans cubit dans l'arbre (écran monté hors de sa route), rien à montrer.
    try {
      context.read<TripGroupCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    return BlocBuilder<TripGroupCubit, TripGroupState>(
      builder: (context, state) {
        if (state.status != TripGroupStatus.loaded) {
          return const SizedBox.shrink();
        }
        final info = state.info;
        final current = info.legOf(announcementId);
        if (current == null) return const SizedBox.shrink();
        return Padding(
          padding: padding,
          child: _Card(info: info, current: current, onOpenLeg: onOpenLeg),
        ).animate().fadeIn(duration: 250.ms, curve: Curves.easeOutCubic);
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.info,
    required this.current,
    required this.onOpenLeg,
  });

  final TripLegsInfo info;
  final TripLegSummary current;
  final ValueChanged<TripLegSummary> onOpenLeg;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Container(
      key: const Key('trip-legs-card'),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route_rounded, color: cs.primary, size: 20),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  l.tripLegsDetailTitle(current.legIndex, info.legCount),
                  style: tt.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          for (final leg in info.legs)
            _LegRow(
              leg: leg,
              isCurrent: leg.id == current.id,
              locale: locale,
              onTap: leg.id == current.id ? null : () => onOpenLeg(leg),
            ),
        ],
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({
    required this.leg,
    required this.isCurrent,
    required this.locale,
    required this.onTap,
  });

  final TripLegSummary leg;
  final bool isCurrent;
  final String locale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cancelled = leg.status == 'CANCELLED';
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrent ? cs.primary : cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${leg.legIndex}',
              style: tt.labelMedium?.copyWith(
                color: isCurrent ? cs.onPrimary : cs.onPrimaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${leg.departureCity} → ${leg.arrivalCity}',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isCurrent
                      ? '${DateFormat.MMMEd(locale).format(leg.departureDate)} · ${l.tripLegsDetailCurrent}'
                      : DateFormat.MMMEd(locale).format(leg.departureDate),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(DonyIcons.chevron, color: cs.onSurfaceVariant, size: 20),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: l.tripLegsDetailOpenSemantics(leg.departureCity, leg.arrivalCity),
      excludeSemantics: true,
      child: InkWell(
        key: Key('trip-leg-open-${leg.id}'),
        borderRadius: BorderRadius.circular(DonyRadius.md),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: row,
        ),
      ),
    );
  }
}
