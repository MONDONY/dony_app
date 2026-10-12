import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/airline_logo.dart';
import 'package:dony/features/flights/presentation/widgets/flight_stamp.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_route.dart';
import 'package:dony/features/matching/presentation/widgets/billet_perforation.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Une offre de vol sous la forme du billet Yadony (même anatomie que
/// `ColisBillet`) : en-tête compagnie + tampon, corridor des codes, dates,
/// perforation, puis talon avec le prix et « Voir l'offre ».
class FlightBilletCard extends StatelessWidget {
  const FlightBilletCard({
    super.key,
    required this.offer,
    required this.originName,
    required this.destinationName,
    required this.onOpen,
    this.cheapest = false,
    this.fastest = false,
    this.opening = false,
  });

  final FlightOffer offer;

  /// Noms des villes saisies dans le formulaire (l'offre ne porte que des codes).
  final String originName;
  final String destinationName;
  final VoidCallback? onOpen;
  final bool cheapest;
  final bool fastest;

  /// Le lien partenaire est en cours de récupération : le bouton tourne.
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final airline = offer.airlineName ?? offer.airlineCode ?? '';
    final via = FlightFormat.stopsAndDuration(l, offer);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        boxShadow: DonyShadow.md,
      ),
      // Pas de clip : les encoches de BilletPerforation débordent des bords.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base,
              DonySpacing.base,
              DonySpacing.base,
              DonySpacing.sm,
            ),
            child: Row(
              children: [
                AirlineLogo(
                  code: offer.airlineCode,
                  logoUrl: offer.logoUrl,
                  name: airline,
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
                if (cheapest || fastest) ...[
                  const SizedBox(width: DonySpacing.sm),
                  FlightStamp(
                    label: cheapest
                        ? l.flightsStampCheapest
                        : l.flightsStampFastest,
                    color: cheapest ? cs.success : cs.primary,
                  ),
                ],
              ],
            ),
          ),
          BilletCorridor(
            departureCity: originName,
            arrivalCity: destinationName,
            departureCode: offer.departureCode,
            arrivalCode: offer.arrivalCode,
          ),
          if (via.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: DonySpacing.xs),
              child: Text(
                via,
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _Dates(offer: offer),
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
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FlightFormat.price(offer.price, offer.currency),
                        style: tt.headlineMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l.flightsPriceDisclaimer,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                DonyButton(
                  key: Key('flight-open-${offer.offerPath}'),
                  label: l.flightsOpenOffer,
                  onPressed: onOpen,
                  isLoading: opening,
                  fullWidth: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aller à gauche, retour à droite (« - » si inconnu).
class _Dates extends StatelessWidget {
  const _Dates({required this.offer});

  final FlightOffer offer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final labelStyle = tt.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = tt.bodySmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    String value(DateTime? d) => d == null ? '-' : FlightFormat.dateTime(l, d);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.sm,
        DonySpacing.base,
        DonySpacing.base,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.flightsOutboundLabel, style: labelStyle),
                Text(value(offer.departureAt), style: valueStyle),
              ],
            ),
          ),
          if (offer.isRoundTrip) ...[
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l.flightsReturnLabel, style: labelStyle),
                  Text(
                    value(offer.returnAt),
                    style: valueStyle,
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
