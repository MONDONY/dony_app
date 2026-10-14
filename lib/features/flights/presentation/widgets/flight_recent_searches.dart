import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// « Vos recherches » : l'historique local, chaque ligne relance sa
/// recherche d'un tap.
class FlightRecentSearches extends StatelessWidget {
  const FlightRecentSearches({
    super.key,
    required this.recents,
    required this.onOpen,
    required this.onClear,
    this.now,
  });

  final List<FlightRecentSearch> recents;
  final ValueChanged<FlightRecentSearch> onOpen;
  final VoidCallback onClear;

  /// Horloge figée des tests ; `DateTime.now()` sinon.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final at = now ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.base,
            DonySpacing.sm,
            0,
          ),
          child: FlightSectionTitle(
            title: l.flightsRecentTitle,
            action: l.flightsRecentClear,
            onAction: onClear,
            actionKey: const Key('flights-recent-clear'),
          ),
        ),
        for (final (i, r) in recents.indexed)
          _RecentRow(
            key: Key('flights-recent-$i'),
            recent: r,
            now: at,
            onTap: () => onOpen(r),
          ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    super.key,
    required this.recent,
    required this.now,
    required this.onTap,
  });

  final FlightRecentSearch recent;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final r = recent;
    final price = r.lowestPrice;
    const tabular = [FontFeature.tabularFigures()];

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.lg,
            vertical: DonySpacing.sm + DonySpacing.xxs,
          ),
          child: Row(
            children: [
              FlightCodeThumb(code: r.destination.code),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FlightFormat.route(
                        l,
                        r.origin.name,
                        r.destination.name,
                        roundTrip: r.roundTrip,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.headlineSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        FlightFormat.dates(l, r.departure, r.returnDate),
                        l.flightsPassengers(r.passengers.total),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price == null
                        ? l.flightsRecentNoPrice
                        : FlightFormat.price(price, r.currency ?? 'EUR'),
                    style: price == null
                        ? tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)
                        : tt.headlineSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFeatures: tabular,
                          ),
                  ),
                  Text(
                    FlightFormat.age(l, r.searchedAt, now),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vignette colorée portant le code IATA d'une destination. La teinte est
/// tirée du code : une même ville garde toujours la même couleur.
class FlightCodeThumb extends StatelessWidget {
  const FlightCodeThumb({super.key, required this.code});

  final String code;

  // Couleurs primitives intentionnelles : illustration, pas un rôle de thème.
  static const _gradients = <(Color, Color)>[
    (DonyColors.terra400, DonyColors.terra600),
    (DonyColors.success500, DonyColors.success700),
    (DonyColors.blue400, DonyColors.blue600),
    (DonyColors.ink400, DonyColors.ink600),
    (DonyColors.terra600, DonyColors.terra800),
    (DonyColors.sand500, DonyColors.terra700),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final hash = code.codeUnits.fold<int>(
      0,
      (h, c) => (h * 31 + c) & 0x7fffffff,
    );
    final (from, to) = _gradients[hash % _gradients.length];
    return ExcludeSemantics(
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [from, to],
          ),
        ),
        child: Text(
          code,
          style: tt.headlineSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: DonyColors.neutral0,
          ),
        ),
      ),
    );
  }
}
