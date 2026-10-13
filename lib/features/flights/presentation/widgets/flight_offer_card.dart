import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/airline_logo.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pastille de l'en-tête d'une carte.
enum FlightOfferBadge { cheapest, fastest }

/// Une offre de vol des résultats : compagnie, une ligne par trajet (aller,
/// puis retour en aller-retour) avec horaires, durée et escales, puis le
/// site vendeur et le prix. Toute la carte ouvre l'offre chez le partenaire.
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
  });

  final FlightOffer offer;
  final VoidCallback? onOpen;
  final FlightOfferBadge? badge;

  /// Le lien partenaire est en cours de récupération.
  final bool opening;

  /// Vols à quelques jours des dates demandées (`nearbyDates` du back) : la
  /// date de départ de chaque trajet s'affiche sous son aéroport, en
  /// terracotta quand elle sort des dates demandées. Faux : carte inchangée.
  final bool showDates;

  /// Dates demandées, pour repérer celles qui diffèrent ; `null` = toutes
  /// les dates, rien n'est alors mis en évidence.
  final FlightWhen? requestedDeparture;
  final FlightWhen? requestedReturn;

  /// Pastille verte d'un vol trouvé par une alerte (« −61 € sous votre
  /// prix »), à la place de [badge].
  final String? savingsLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final o = offer;
    final airline = o.airlineName ?? o.airlineCode ?? '';
    final header = [
      airline,
      if (o.flightNumber != null && o.flightNumber!.isNotEmpty)
        _flightNumber(o),
    ].where((s) => s.isNotEmpty).join(' · ');
    final radius = BorderRadius.circular(DonyRadius.card);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(color: cs.outline.withValues(alpha: 0.8)),
        boxShadow: DonyShadow.sm,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('flight-open-${o.offerPath}'),
          borderRadius: radius,
          onTap: opening ? null : onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.md + DonySpacing.xxs,
                  DonySpacing.md - 1,
                  DonySpacing.md + DonySpacing.xxs,
                  DonySpacing.xs,
                ),
                child: Row(
                  children: [
                    AirlineLogo(
                      code: o.airlineCode,
                      logoUrl: o.logoUrl,
                      name: airline,
                      size: 24,
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Text(
                        header,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (savingsLabel != null) ...[
                      const SizedBox(width: DonySpacing.sm),
                      _SavingsTag(label: savingsLabel!),
                    ] else if (badge != null) ...[
                      const SizedBox(width: DonySpacing.sm),
                      _Badge(badge: badge!),
                    ],
                  ],
                ),
              ),
              _LegRow(
                key: const Key('flight-leg-outbound'),
                departure: o.departureAt,
                arrival: o.arrivalAt,
                fromCode: o.departureCode,
                toCode: o.arrivalCode,
                minutes: o.outboundMinutes,
                transfers: o.transfers,
                dayOffset: o.arrivalDayOffset,
                date: showDates
                    ? _LegDate.of(o.departureAt, requestedDeparture)
                    : null,
              ),
              if (o.isRoundTrip)
                _LegRow(
                  key: const Key('flight-leg-return'),
                  departure: o.returnAt,
                  arrival: o.returnArrivalAt,
                  fromCode: o.arrivalCode,
                  toCode: o.departureCode,
                  minutes: o.returnDurationMinutes,
                  transfers: o.returnTransfers,
                  dayOffset: o.returnArrivalDayOffset,
                  date: showDates
                      ? _LegDate.of(o.returnAt, requestedReturn)
                      : null,
                ),
              const SizedBox(height: DonySpacing.xs + DonySpacing.xxs),
              const FlightDashedLine(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.md + DonySpacing.xxs,
                  DonySpacing.sm + DonySpacing.xxs,
                  DonySpacing.md + DonySpacing.xxs,
                  DonySpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _Via(gate: o.gate)),
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
                      const SizedBox(width: DonySpacing.sm),
                    ],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          FlightFormat.price(o.price, o.currency),
                          style: tt.headlineMedium?.copyWith(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: DonySpacing.xs),
                        Text(
                          l.flightsPriceIndicative,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ],
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

  /// « AF 702 » : le numéro reçu seul (« 702 ») est précédé du code de la
  /// compagnie.
  static String _flightNumber(FlightOffer o) {
    final n = o.flightNumber!.trim();
    final code = o.airlineCode;
    if (code == null || RegExp('^[A-Za-z]').hasMatch(n)) return n;
    return '$code $n';
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

/// « −61 € sous votre prix », en vert.
class _SavingsTag extends StatelessWidget {
  const _SavingsTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const Key('flight-offer-savings'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: tt.bodySmall?.copyWith(
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: cs.success,
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
    super.key,
    required this.departure,
    required this.arrival,
    required this.fromCode,
    required this.toCode,
    required this.minutes,
    required this.transfers,
    required this.dayOffset,
    this.date,
  });

  final DateTime? departure;
  final DateTime? arrival;
  final String fromCode;
  final String toCode;
  final int? minutes;
  final int? transfers;
  final int dayOffset;

  /// Date du départ du trajet, affichée sous l'aéroport de départ.
  final _LegDate? date;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final start = FlightFormat.time(l, departure);
    final end = FlightFormat.time(l, arrival);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md + DonySpacing.xxs,
        vertical: DonySpacing.xs + DonySpacing.xxs,
      ),
      child: Row(
        children: [
          _Stop(time: start, code: fromCode, end: false, date: date),
          const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
          Expanded(
            child: _Middle(minutes: minutes, transfers: transfers),
          ),
          const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
          _Stop(
            time: end,
            code: toCode,
            end: true,
            dayOffset: end == null ? 0 : dayOffset,
          ),
        ],
      ),
    );
  }
}

/// Heure en grand et code de l'aéroport dessous.
class _Stop extends StatelessWidget {
  const _Stop({
    required this.time,
    required this.code,
    required this.end,
    this.dayOffset = 0,
    this.date,
  });

  final String? time;
  final String code;
  final bool end;
  final int dayOffset;
  final _LegDate? date;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const tabular = [FontFeature.tabularFigures()];
    final big = tt.headlineMedium?.copyWith(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
      height: 1.05,
      fontFeatures: tabular,
    );
    final small = tt.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
    final align = end ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final dateLine = date == null ? null : _DateLine(date: date!);
    if (time == null) {
      // Heure inconnue : le code seul, à la place de l'heure.
      final alone = Text(
        code,
        style: big?.copyWith(color: cs.onSurfaceVariant),
      );
      if (dateLine == null) return alone;
      return Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [alone, dateLine],
      );
    }
    return Column(
      crossAxisAlignment: align,
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
                      ),
                    ),
                  ),
                ),
            ],
          ),
          style: big,
        ),
        Text(code, style: small),
        ?dateLine,
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

/// Durée, trait avec les escales en terracotta et le petit avion, puis
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
              Divider(height: 1.5, thickness: 1.5, color: cs.outline),
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
              PositionedDirectional(
                end: -2,
                child: DonyIcon('plane', size: 13, color: cs.onSurfaceVariant),
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
