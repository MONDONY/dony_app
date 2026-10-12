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
