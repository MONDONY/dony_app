import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/airline_logo.dart';
import 'package:dony/features/flights/presentation/widgets/flight_stamp.dart';
import 'package:dony/features/matching/presentation/widgets/billet_perforation.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Mini-billet du carrousel « Bons plans pour vous » : même anatomie que le
/// billet des résultats, en plus compact. Le toucher lance la recherche de
/// ce trajet sur son mois.
class FlightDealCard extends StatelessWidget {
  const FlightDealCard({super.key, required this.deal, required this.onTap});

  static const width = 244.0;

  final FlightDeal deal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final offer = deal.offer;
    final airline = offer.airlineName ?? offer.airlineCode ?? '';
    final departure = offer.departureAt;
    final stops = FlightFormat.stops(l, offer.transfers);
    final when = [
      if (departure != null)
        l.flightsDealFrom(FlightFormat.dateTime(l, departure, withTime: false)),
      ?stops,
    ].join(' · ');
    final codeStyle = tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800);

    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: l.flightsDealSemantics(
          offer.originCode,
          offer.destinationCode,
          FlightFormat.price(offer.price, offer.currency),
          deal.discountPercent,
        ),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              boxShadow: DonyShadow.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.md,
                    DonySpacing.md,
                    DonySpacing.md,
                    DonySpacing.xs,
                  ),
                  child: Row(
                    children: [
                      AirlineLogo(
                        code: offer.airlineCode,
                        logoUrl: offer.logoUrl,
                        name: airline,
                        size: 26,
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          airline.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      FlightStamp(
                        label: l.flightsDealDiscount(deal.discountPercent),
                        color: cs.success,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                  ),
                  child: Row(
                    children: [
                      Text(offer.departureCode, style: codeStyle),
                      Expanded(
                        child: DonyIcon(
                          'plane',
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(offer.arrivalCode, style: codeStyle),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.md,
                    DonySpacing.xs,
                    DonySpacing.md,
                    DonySpacing.sm,
                  ),
                  child: Text(
                    when,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                BilletPerforation(
                  notchColor: Theme.of(context).scaffoldBackgroundColor,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(DonyRadius.card),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                    vertical: DonySpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        FlightFormat.price(offer.price, offer.currency),
                        style: tt.titleLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          l.flightsDealVsUsual,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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

/// Mini-billet compact d'un bon plan, pour le bloc « Billets d'avion » du hub
/// Activités : compagnie, trajet, date et escales, puis le prix et l'écart au
/// prix habituel sous la perforation. Plus étroit que [FlightDealCard] pour
/// laisser deviner le billet suivant sur un téléphone de 360 dp.
class FlightDealMiniCard extends StatelessWidget {
  const FlightDealMiniCard({
    super.key,
    required this.deal,
    required this.onTap,
  });

  static const width = 176.0;

  final FlightDeal deal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final offer = deal.offer;
    final airline = offer.airlineName ?? offer.airlineCode ?? '';
    final departure = offer.departureAt;
    final stops = FlightFormat.stops(l, offer.transfers);
    final when = [
      // « 12 déc. » sans le jour de la semaine : sur 176 px, la date et les
      // escales tiennent ensemble sur une ligne.
      if (departure != null)
        l.flightsDealFrom(FlightFormat.dayMonth(l, departure)),
      ?stops,
    ].join(' · ');
    final codeStyle = tt.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 17,
    );

    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: l.flightsDealSemantics(
          offer.originCode,
          offer.destinationCode,
          FlightFormat.price(offer.price, offer.currency),
          deal.discountPercent,
        ),
        excludeSemantics: true,
        child: DonyPressable(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              boxShadow: DonyShadow.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.md,
                    DonySpacing.md,
                    DonySpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      AirlineLogo(
                        code: offer.airlineCode,
                        logoUrl: offer.logoUrl,
                        name: airline,
                        size: 20,
                      ),
                      const SizedBox(width: DonySpacing.xs + DonySpacing.xxs),
                      Expanded(
                        child: Text(
                          airline.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.md,
                    DonySpacing.sm,
                    DonySpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Text(offer.departureCode, style: codeStyle),
                      Expanded(
                        child: DonyIcon(
                          'plane',
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(offer.arrivalCode, style: codeStyle),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.md,
                    DonySpacing.xxs,
                    DonySpacing.md,
                    DonySpacing.sm,
                  ),
                  child: Text(
                    when,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                BilletPerforation(
                  notchColor: Theme.of(context).scaffoldBackgroundColor,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(DonyRadius.card),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                    vertical: DonySpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            FlightFormat.price(offer.price, offer.currency),
                            style: tt.titleMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      FlightStamp(
                        label: l.flightsDealDiscount(deal.discountPercent),
                        color: cs.success,
                      ),
                    ],
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

/// Squelette d'un [FlightDealMiniCard] pendant le chargement des bons plans.
class FlightDealMiniCardSkeleton extends StatelessWidget {
  const FlightDealMiniCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DonyShimmer(
      child: Container(
        width: FlightDealMiniCard.width,
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          boxShadow: DonyShadow.sm,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                DonySkeletonCircle(diameter: 20),
                SizedBox(width: DonySpacing.sm),
                DonySkeletonBox(width: 70),
              ],
            ),
            SizedBox(height: DonySpacing.md),
            DonySkeletonBox(width: 120, height: 18),
            SizedBox(height: DonySpacing.sm),
            DonySkeletonBox(width: 100),
            SizedBox(height: DonySpacing.lg),
            DonySkeletonBox(width: 80, height: 18),
          ],
        ),
      ),
    );
  }
}
