import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// En-tête des résultats : retour, pastille résumé de la recherche (qui
/// ramène au formulaire), cloche d'alerte prix.
class FlightResultsHeader extends StatelessWidget {
  const FlightResultsHeader({
    super.key,
    required this.route,
    required this.dates,
    required this.onBack,
    this.onCreateAlert,
  });

  final String route;
  final String dates;
  final VoidCallback onBack;

  /// `null` : pas de cloche (écran « Aucun vol », qui propose l'alerte plus
  /// bas).
  final VoidCallback? onCreateAlert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    const tabular = [FontFeature.tabularFigures()];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.sm,
        DonySpacing.xs,
        DonySpacing.xs,
        DonySpacing.sm,
      ),
      child: Row(
        children: [
          FlightRoundButton(
            key: const Key('flights-back'),
            icon: 'arrow-left',
            tooltip: l.commonBack,
            onPressed: onBack,
          ),
          const SizedBox(width: DonySpacing.xs),
          Expanded(
            child: Semantics(
              button: true,
              label: l.flightsSummaryEdit,
              child: DonyPressable(
                key: const Key('flights-summary'),
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                    vertical: DonySpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.lg),
                    border: Border.all(color: cs.outline),
                    boxShadow: DonyShadow.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              route,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.headlineSmall?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: DonySpacing.xs + DonySpacing.xxs,
                          ),
                          DonyIcon(
                            'square-pen',
                            size: 15,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              dates,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFeatures: tabular,
                              ),
                            ),
                          ),
                          const SizedBox(width: DonySpacing.sm),
                          DonyIcon(
                            'user',
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '1',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontFeatures: tabular,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onCreateAlert != null) ...[
            const SizedBox(width: DonySpacing.xs),
            FlightRoundButton(
              key: const Key('flights-create-alert'),
              icon: 'bell',
              tooltip: l.flightsAlertCreateTooltip,
              iconColor: cs.primary,
              onPressed: onCreateAlert,
            ),
          ],
          const DonyFeedbackButton(),
        ],
      ),
    );
  }
}

/// Trois onglets de tri dans une carte, chacun avec le prix et la durée de
/// sa meilleure offre. L'onglet actif est sur fond bleu pâle et souligné.
class FlightSortTabs extends StatelessWidget {
  const FlightSortTabs({
    super.key,
    required this.summaries,
    required this.selected,
    required this.onSelect,
  });

  final Map<FlightResultsTab, FlightTabSummary> summaries;
  final FlightResultsTab selected;
  final ValueChanged<FlightResultsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, tab) in FlightResultsTab.values.indexed) ...[
              if (i > 0)
                VerticalDivider(width: 1, thickness: 1, color: cs.outline),
              Expanded(
                child: _Tab(
                  key: Key('flights-tab-${tab.name}'),
                  label: switch (tab) {
                    FlightResultsTab.cheapest => l.flightsTabCheapest,
                    FlightResultsTab.fastest => l.flightsTabFastest,
                    FlightResultsTab.direct => l.flightsTabDirect,
                  },
                  summary: summaries[tab],
                  selected: tab == selected,
                  onTap: () => onSelect(tab),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.label,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final FlightTabSummary? summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final s = summary;
    final enabled = s != null;
    const tabular = [FontFeature.tabularFigures()];

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: DonyDuration.base,
          curve: DonyCurve.easeOut,
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.sm,
            DonySpacing.sm + 1,
            DonySpacing.sm,
            DonySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surface,
            border: Border(
              bottom: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  s == null
                      ? l.flightsTabNone
                      : FlightFormat.price(s.price, s.offer.currency),
                  maxLines: 1,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    fontFeatures: tabular,
                  ),
                ),
                Text(
                  s?.minutes == null
                      ? ''
                      : FlightFormat.duration(l, s!.minutes!),
                  maxLines: 1,
                  style: tt.bodySmall?.copyWith(
                    height: 1.2,
                    color: cs.onSurfaceVariant,
                    fontFeatures: tabular,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rubrique de la feuille de filtres qu'ouvre une puce.
enum FlightFilterSection { stops, airlines, times }

/// Puces sous les onglets : « Filtres · n » (noire si un filtre est actif),
/// puis Escales, Compagnies et Horaires qui ouvrent la feuille sur leur
/// rubrique.
class FlightFilterChips extends StatelessWidget {
  const FlightFilterChips({
    super.key,
    required this.activeCount,
    required this.onOpen,
    this.showAirlines = true,
    this.showTimes = true,
  });

  final int activeCount;

  /// `null` : la feuille s'ouvre en haut.
  final void Function(FlightFilterSection? section) onOpen;
  final bool showAirlines;
  final bool showTimes;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: kDonyMinTapTarget,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        children: [
          _Chip(
            key: const Key('flights-filters'),
            label: activeCount > 0
                ? l.flightsChipFiltersCount(activeCount)
                : l.flightsFiltersTitle,
            icon: 'sliders-horizontal',
            dark: activeCount > 0,
            onTap: () => onOpen(null),
          ),
          _Chip(
            key: const Key('flights-chip-stops'),
            label: l.flightsFiltersStops,
            onTap: () => onOpen(FlightFilterSection.stops),
          ),
          if (showAirlines)
            _Chip(
              key: const Key('flights-chip-airlines'),
              label: l.flightsFiltersAirlines,
              onTap: () => onOpen(FlightFilterSection.airlines),
            ),
          if (showTimes)
            _Chip(
              key: const Key('flights-chip-times'),
              label: l.flightsChipTimes,
              onTap: () => onOpen(FlightFilterSection.times),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.dark = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = dark ? cs.onInverseSurface : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: DonySpacing.sm),
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: DonyDuration.base,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
              decoration: BoxDecoration(
                color: dark ? cs.inverseSurface : cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(
                  color: dark ? cs.inverseSurface : cs.outline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    DonyIcon(icon!, size: 15, color: fg),
                    const SizedBox(width: DonySpacing.xs + DonySpacing.xxs),
                  ],
                  Text(
                    label,
                    style: tt.bodySmall?.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau sable en tête des résultats quand le back n'a rien trouvé aux
/// jours demandés et renvoie des vols à [days] jours près.
class FlightNearbyDatesNotice extends StatelessWidget {
  const FlightNearbyDatesNotice({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceWarm,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('calendar', size: 18, color: cs.secondary),
          const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
          Expanded(
            child: Text(
              context.l10n.flightsNearbyDatesNotice(days),
              style: tt.bodySmall?.copyWith(
                fontSize: 12.5,
                height: 1.45,
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encart sable « Une compagnie manque ? » : ouvre la recherche Aviasales
/// complète du trajet.
class FlightAllAirlinesCard extends StatelessWidget {
  const FlightAllAirlinesCard({
    super.key,
    required this.onTap,
    this.opening = false,
  });

  final VoidCallback onTap;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      button: true,
      child: DonyPressable(
        onTap: opening ? () {} : onTap,
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.md + DonySpacing.xxs),
          decoration: BoxDecoration(
            color: cs.surfaceWarm,
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.flightsMoreTitle,
                      style: tt.headlineSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      l.flightsMoreBody,
                      style: tt.bodySmall?.copyWith(
                        fontSize: 12.5,
                        height: 1.45,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.inverseSurface,
                  shape: BoxShape.circle,
                ),
                child: opening
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onInverseSurface,
                        ),
                      )
                    : DonyIcon(
                        'external-link',
                        size: 17,
                        color: cs.onInverseSurface,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une sortie proposée par l'écran « Aucun vol ».
class FlightSuggestion {
  const FlightSuggestion({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final Key key;
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Icône terracotta (alerte) plutôt que bleue.
  final bool accent;
}

/// Écran « Aucun vol à ces dates » (ou erreur) : carte d'explication, puis
/// « Essayez plutôt » et des sorties concrètes.
class FlightEmptyResults extends StatelessWidget {
  const FlightEmptyResults({
    super.key,
    required this.title,
    required this.body,
    required this.suggestions,
  });

  final String title;
  final String body;
  final List<FlightSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return ListView(
      key: const Key('flights-empty'),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.xs,
        DonySpacing.base,
        flightNavBarReserve(context) + DonySpacing.huge,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(DonySpacing.base + DonySpacing.xxs),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.xl - 2),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.xl - 2),
                ),
                child: DonyIcon('plane-off', size: 30, color: cs.secondary),
              ),
              const SizedBox(width: DonySpacing.md + DonySpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.headlineMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: tt.bodySmall?.copyWith(
                        fontSize: 12.5,
                        height: 1.45,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.xxs,
              DonySpacing.lg,
              0,
              DonySpacing.sm + DonySpacing.xxs,
            ),
            child: FlightSectionTitle(title: l.flightsTryInstead),
          ),
          for (final s in suggestions) ...[
            _SuggestionRow(suggestion: s),
            const SizedBox(height: DonySpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion});

  final FlightSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = suggestion;
    return Semantics(
      button: true,
      child: DonyPressable(
        key: s.key,
        onTap: s.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md + DonySpacing.xxs,
            vertical: DonySpacing.md,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.accent ? cs.secondaryContainer : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                ),
                child: DonyIcon(
                  s.icon,
                  size: 18,
                  color: s.accent ? cs.secondary : cs.primary,
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: tt.headlineSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      s.subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
