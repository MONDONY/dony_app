import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/airline_logo.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pastille de l'en-tête d'une carte.
enum FlightOfferBadge { cheapest, fastest }

/// Une offre de vol des résultats, à la manière d'Opodo : compagnie, date
/// du vol, puis une ligne d'horaires par trajet (aller, puis retour empilé
/// en aller-retour, chacun avec sa compagnie et sa date). Le prix, en grand,
/// s'aligne à droite de la dernière ligne d'horaires, le site vendeur
/// dessous. Toute la carte ouvre l'offre chez le partenaire.
class FlightOfferCard extends StatelessWidget {
  const FlightOfferCard({
    super.key,
    required this.offer,
    required this.onOpen,
    this.badge,
    this.opening = false,
    this.showDates = false,
    this.requestedDeparture,
    this.requestedReturn,
    this.savingsLabel,
    this.aboveLabel,
  });

  final FlightOffer offer;
  final VoidCallback? onOpen;
  final FlightOfferBadge? badge;

  /// Le lien partenaire est en cours de récupération.
  final bool opening;

  /// Vols à quelques jours des dates demandées (`nearbyDates` du back) : la
  /// date d'un trajet qui sort des dates demandées passe en terracotta.
  /// La date de chaque trajet s'affiche dans tous les cas.
  final bool showDates;

  /// Dates demandées, pour repérer celles qui diffèrent ; `null` = toutes
  /// les dates, rien n'est alors mis en évidence.
  final FlightWhen? requestedDeparture;
  final FlightWhen? requestedReturn;

  /// Pastille verte d'un vol trouvé par une alerte (« −61 € sous votre
  /// prix »), à la place de [badge].
  final String? savingsLabel;

  /// Pastille neutre d'un vol d'une alerte au-dessus de son prix (« +24 €
  /// au-dessus »), à la place de [badge] et de [savingsLabel].
  final String? aboveLabel;

  /// Marge intérieure de la carte.
  static const _pad = DonySpacing.md + DonySpacing.xxs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final o = offer;
    final airline = o.airlineName ?? o.airlineCode ?? '';
    final header = [
      airline,
      if (o.flightNumber != null && o.flightNumber!.isNotEmpty)
        _flightNumber(o),
    ].where((s) => s.isNotEmpty).join(' · ');
    final radius = BorderRadius.circular(DonyRadius.card);

    final Widget? tag = aboveLabel != null
        ? _SavingsTag(label: aboveLabel!, above: true)
        : savingsLabel != null
        ? _SavingsTag(label: savingsLabel!)
        : badge != null
        ? _Badge(badge: badge!)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(color: cs.outline.withValues(alpha: 0.6)),
        boxShadow: DonyShadow.sm,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('flight-open-${o.offerPath}'),
          borderRadius: radius,
          onTap: opening ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_pad, _pad - 2, _pad, _pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Carrier(
                        code: o.airlineCode,
                        logoUrl: o.logoUrl,
                        name: airline,
                        label: header,
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: DonySpacing.sm),
                      tag,
                    ],
                  ],
                ),
                const SizedBox(height: DonySpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegBlock(
                            key: const Key('flight-leg-outbound'),
                            departure: o.departureAt,
                            arrival: o.arrivalAt,
                            fromCode: o.departureCode,
                            toCode: o.arrivalCode,
                            minutes: o.outboundMinutes,
                            transfers: o.transfers,
                            dayOffset: o.arrivalDayOffset,
                            date: _LegDate.of(
                              o.departureAt,
                              showDates ? requestedDeparture : null,
                            ),
                          ),
                          if (o.isRoundTrip) ...[
                            const SizedBox(height: DonySpacing.base),
                            _Carrier(
                              code: o.airlineCode,
                              logoUrl: o.logoUrl,
                              name: airline,
                              label: airline,
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            _LegBlock(
                              key: const Key('flight-leg-return'),
                              departure: o.returnAt,
                              arrival: o.returnArrivalAt,
                              fromCode: o.arrivalCode,
                              toCode: o.departureCode,
                              minutes: o.returnDurationMinutes,
                              transfers: o.returnTransfers,
                              dayOffset: o.returnArrivalDayOffset,
                              date: _LegDate.of(
                                o.returnAt,
                                showDates ? requestedReturn : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    _PriceBlock(offer: o, opening: opening),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// « AF 702 » : le numéro reçu seul (« 702 ») est précédé du code de la
  /// compagnie.
  static String _flightNumber(FlightOffer o) {
    final n = o.flightNumber!.trim();
    final code = o.airlineCode;
    if (code == null || RegExp('^[A-Za-z]').hasMatch(n)) return n;
    return '$code $n';
  }
}

/// Logo rond de la compagnie et son nom (numéro de vol compris), en gris.
class _Carrier extends StatelessWidget {
  const _Carrier({
    required this.code,
    required this.logoUrl,
    required this.name,
    required this.label,
  });

  final String? code;
  final String? logoUrl;
  final String name;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        AirlineLogo(code: code, logoUrl: logoUrl, name: name, size: 22),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Prix en très grand, aligné à droite, le site vendeur dessous (« via
/// Kiwi.com »), ou « prix indicatif » quand le site est inconnu.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.offer, required this.opening});

  final FlightOffer offer;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final gate = offer.gate;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (opening) ...[
            Semantics(
              label: l.flightsOfferOpening,
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              FlightFormat.price(offer.price, offer.currency),
              key: const Key('flight-offer-price'),
              maxLines: 1,
              style: tt.headlineMedium?.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.05,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          if (gate != null && gate.isNotEmpty)
            _Via(gate: gate)
          else
            Text(
              l.flightsPriceIndicative,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}

/// Date du trajet au-dessus de sa ligne d'horaires.
class _LegBlock extends StatelessWidget {
  const _LegBlock({
    super.key,
    required this.departure,
    required this.arrival,
    required this.fromCode,
    required this.toCode,
    required this.minutes,
    required this.transfers,
    required this.dayOffset,
    required this.date,
  });

  final DateTime? departure;
  final DateTime? arrival;
  final String fromCode;
  final String toCode;
  final int? minutes;
  final int? transfers;
  final int dayOffset;
  final _LegDate? date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (date != null) ...[
          _DateLine(date: date!),
          const SizedBox(height: DonySpacing.xs),
        ],
        _LegRow(
          departure: departure,
          arrival: arrival,
          fromCode: fromCode,
          toCode: toCode,
          minutes: minutes,
          transfers: transfers,
          dayOffset: dayOffset,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge});

  final FlightOfferBadge badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final cheapest = badge == FlightOfferBadge.cheapest;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: cheapest ? cs.secondaryContainer : cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        cheapest ? l.flightsStampCheapest : l.flightsStampFastest,
        style: tt.bodySmall?.copyWith(
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: cheapest ? cs.onSecondaryContainer : cs.primary,
        ),
      ),
    );
  }
}

/// « −61 € sous votre prix », en vert, ou « +24 € au-dessus », en gris.
class _SavingsTag extends StatelessWidget {
  const _SavingsTag({required this.label, this.above = false});

  final String label;
  final bool above;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      key: Key(above ? 'flight-offer-above' : 'flight-offer-savings'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: above ? cs.surfaceContainerHighest : cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: tt.bodySmall?.copyWith(
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: above ? cs.onSurfaceVariant : cs.success,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Une ligne de trajet : départ à gauche, durée et escales au centre,
/// arrivée à droite. Une heure inconnue laisse le code de l'aéroport seul
/// à sa place, sans heure inventée.
class _LegRow extends StatelessWidget {
  const _LegRow({
    required this.departure,
    required this.arrival,
    required this.fromCode,
    required this.toCode,
    required this.minutes,
    required this.transfers,
    required this.dayOffset,
  });

  final DateTime? departure;
  final DateTime? arrival;
  final String fromCode;
  final String toCode;
  final int? minutes;
  final int? transfers;
  final int dayOffset;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final start = FlightFormat.time(l, departure);
    final end = FlightFormat.time(l, arrival);
    return Row(
      children: [
        _Stop(time: start, code: fromCode, end: false),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: _Middle(minutes: minutes, transfers: transfers),
        ),
        const SizedBox(width: DonySpacing.sm),
        _Stop(
          time: end,
          code: toCode,
          end: true,
          dayOffset: end == null ? 0 : dayOffset,
        ),
      ],
    );
  }
}

/// Heure en grand et code de l'aéroport dessous ; « +1 » en exposant quand
/// l'arrivée tombe un autre jour.
class _Stop extends StatelessWidget {
  const _Stop({
    required this.time,
    required this.code,
    required this.end,
    this.dayOffset = 0,
  });

  final String? time;
  final String code;
  final bool end;
  final int dayOffset;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const tabular = [FontFeature.tabularFigures()];
    final big = tt.headlineMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
      height: 1.1,
      fontFeatures: tabular,
    );
    final small = tt.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.3,
    );

    if (time == null) {
      // Heure inconnue : le code seul, à la place de l'heure.
      return Text(code, style: big?.copyWith(color: cs.onSurfaceVariant));
    }
    return Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: time,
            children: [
              if (dayOffset > 0)
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 2),
                    child: Text(
                      '+$dayOffset',
                      key: const Key('flight-day-offset'),
                      style: tt.bodySmall?.copyWith(
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: cs.secondary,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          style: big,
        ),
        Text(code, style: small),
      ],
    );
  }
}

/// Jour de départ d'un trajet et s'il sort des dates demandées.
class _LegDate {
  const _LegDate(this.day, {required this.shifted});

  final DateTime day;
  final bool shifted;

  static _LegDate? of(DateTime? at, FlightWhen? requested) {
    if (at == null) return null;
    final day = DateTime(at.year, at.month, at.day);
    final shifted =
        requested != null &&
        (day.isBefore(requested.first) || day.isAfter(requested.last));
    return _LegDate(day, shifted: shifted);
  }
}

/// « mar. 22 déc. », en terracotta quand le jour diffère de la demande.
class _DateLine extends StatelessWidget {
  const _DateLine({required this.date});

  final _LegDate date;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Text(
      DateFormat.MMMEd(l.localeName).format(date.day),
      key: Key(date.shifted ? 'flight-leg-date-shifted' : 'flight-leg-date'),
      maxLines: 1,
      style: tt.bodySmall?.copyWith(
        height: 1.2,
        fontWeight: date.shifted ? FontWeight.w700 : FontWeight.w500,
        color: date.shifted ? cs.secondary : cs.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Durée, trait fin avec un petit rond par escale, puis
/// « Direct » en vert ou « 1 escale » en terracotta.
class _Middle extends StatelessWidget {
  const _Middle({required this.minutes, required this.transfers});

  final int? minutes;
  final int? transfers;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final stops = transfers;
    final label = FlightFormat.stops(l, stops);
    final small = tt.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          minutes == null ? '' : FlightFormat.duration(l, minutes!),
          style: small,
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Divider(height: 1, thickness: 1, color: cs.outline),
              if (stops != null && stops > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < stops.clamp(1, 3); i++)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.secondary, width: 1.8),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        if (label != null)
          Text(
            label,
            style: small?.copyWith(
              fontWeight: FontWeight.w700,
              color: stops == 0 ? cs.success : cs.secondary,
            ),
          ),
      ],
    );
  }
}

/// « via Kiwi.com », le site en gras.
class _Via extends StatelessWidget {
  const _Via({required this.gate});

  final String? gate;

  @override
  Widget build(BuildContext context) {
    final g = gate;
    if (g == null) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final text = l.flightsVia(g);
    final at = text.indexOf(g);
    final base = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    if (at < 0) return Text(text, style: base);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: g,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
          TextSpan(text: text.substring(at + g.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}
