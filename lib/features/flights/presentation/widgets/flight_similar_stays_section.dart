import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/bloc/flight_link_cubit.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_passengers.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/presentation/widgets/flight_offer_card.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Section des allers-retours du même trajet à d'autres dates, de durée de
/// séjour proche (`similarOffers` du back) : « Séjours de 21 à 35 jours »,
/// le rappel que les dates diffèrent de la recherche, puis une carte par
/// offre, dates de l'aller et du retour visibles (en couleur d'accent hors
/// des dates demandées) et pastille de la durée du séjour.
///
/// Ni les onglets de tri ni les filtres des résultats ne s'y appliquent.
/// Une carte touchée s'ouvre chez le partenaire par [FlightLinkCubit]
/// (`openSimilar`), comme les autres offres.
class FlightSimilarStaysSection extends StatelessWidget {
  const FlightSimilarStaysSection({
    super.key = const Key('flights-similar'),
    required this.offers,
    required this.range,
    this.requestedDeparture,
    this.requestedReturn,
    this.passengers = FlightPassengers.single,
  });

  final List<FlightOffer> offers;

  /// Plage de durée de séjour du titre ; `null` : titre sans plage.
  final ({int min, int max})? range;

  /// Dates de la recherche, pour mettre en évidence celles qui diffèrent.
  final FlightWhen? requestedDeparture;
  final FlightWhen? requestedReturn;

  /// Passagers de la recherche : mention du prix et lien du partenaire.
  final FlightPassengers passengers;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final r = range;
    final title = r == null
        ? l.flightsSimilarTitleFallback
        : r.min == r.max
        ? l.flightsSimilarTitleSingle(r.min)
        : l.flightsSimilarTitle(r.min, r.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FlightSectionTitle(title: title),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                l.flightsSimilarSubtitle,
                style: tt.bodySmall?.copyWith(
                  fontSize: 12.5,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final offer in offers) ...[
          const SizedBox(height: DonySpacing.sm + 2),
          BlocSelector<FlightLinkCubit, FlightLinkState, bool>(
            key: Key('flights-similar-${offer.offerPath}'),
            selector: (s) => s.openingPath == offer.offerPath,
            builder: (context, opening) => FlightOfferCard(
              offer: offer,
              opening: opening,
              showDates: true,
              requestedDeparture: requestedDeparture,
              requestedReturn: requestedReturn,
              stayDays: offer.stayDays,
              passengers: passengers,
              onOpen: () => context.read<FlightLinkCubit>().openSimilar(
                offer,
                passengers: passengers,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// « 28 j » : durée du séjour d'un aller-retour, en pastille d'accent dans
/// l'en-tête d'une carte d'offre.
class FlightStayTag extends StatelessWidget {
  const FlightStayTag({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      label: l.flightsStayDaysSemantics(days),
      excludeSemantics: true,
      child: Container(
        key: const Key('flight-offer-stay'),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.xxs + 1,
        ),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('calendar', size: 12, color: cs.secondary),
            const SizedBox(width: DonySpacing.xs),
            Text(
              l.flightsStayDays(days),
              maxLines: 1,
              style: tt.bodySmall?.copyWith(
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: cs.secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
