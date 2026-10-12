import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Formulaire de l'onglet Billets, à plat sur toute la largeur : lignes
/// séparées par un trait fin décalé à gauche, libellé gris et valeur en
/// gras, bouton d'inversion posé sur le séparateur des deux villes.
class FlightSearchForm extends StatelessWidget {
  const FlightSearchForm({
    super.key,
    required this.query,
    required this.onPickCity,
    required this.onSwap,
    required this.onPickDates,
    required this.onDirectChanged,
  });

  final FlightSearchQuery query;

  /// [departure] vrai : champ de départ touché.
  final void Function({required bool departure}) onPickCity;
  final VoidCallback onSwap;
  final VoidCallback onPickDates;
  final ValueChanged<bool> onDirectChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final q = query;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.symmetric(horizontal: BorderSide(color: cs.outline)),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  _Row(
                    key: const Key('flights-origin'),
                    label: l.flightsFieldDeparture,
                    onTap: () => onPickCity(departure: true),
                    child: _PlaceValue(place: q.origin),
                  ),
                  _Row(
                    key: const Key('flights-destination'),
                    label: l.flightsFieldDestination,
                    onTap: () => onPickCity(departure: false),
                    child: _PlaceValue(place: q.destination),
                  ),
                ],
              ),
              // Les deux lignes ont la même hauteur : le milieu de la pile
              // tombe sur leur séparateur.
              PositionedDirectional(
                end: DonySpacing.lg - (kDonyMinTapTarget - 34) / 2,
                top: 0,
                bottom: 0,
                child: Center(child: _SwapButton(onPressed: onSwap)),
              ),
            ],
          ),
          _DatesRow(query: q, onTap: onPickDates),
          _Row(
            last: true,
            child: FlightCheckRow(
              key: const Key('flights-direct'),
              label: l.flightsDirectOnly,
              value: q.directOnly,
              onChanged: onDirectChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne du formulaire : marge gauche, trait fin en bas sauf la dernière.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    this.label,
    required this.child,
    this.onTap,
    this.last = false,
  });

  final String? label;
  final Widget child;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(start: DonySpacing.lg),
      padding: EdgeInsetsDirectional.fromSTEB(
        0,
        label == null ? DonySpacing.xs : DonySpacing.md,
        DonySpacing.lg,
        label == null ? DonySpacing.xs : DonySpacing.md,
      ),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: label == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(label!),
                const SizedBox(height: DonySpacing.xxs),
                child,
              ],
            ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: tt.bodySmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    );
  }
}

/// Style des valeurs : Hanken Grotesk 17, gras.
TextStyle? _valueStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .headlineMedium
    ?.copyWith(fontSize: 17, letterSpacing: -0.17, height: 1.3);

/// « PAR · Paris, France », le code en bleu ; « Choisir une ville » à vide.
class _PlaceValue extends StatelessWidget {
  const _PlaceValue({required this.place});

  final FlightPlace? place;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final style = _valueStyle(context);
    final p = place;
    if (p == null) {
      return Text(
        l.flightsFieldChooseCity,
        style: style?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    final named = p.name != p.code;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: p.code,
            style: TextStyle(color: cs.primary),
          ),
          if (named) TextSpan(text: ' · ${FlightFormat.placeName(l, p)}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(color: cs.onSurface),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Tooltip(
      message: l.flightsSwapTooltip,
      child: Semantics(
        button: true,
        label: l.flightsSwapTooltip,
        excludeSemantics: true,
        child: DonyPressable(
          key: const Key('flights-swap'),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: kDonyMinTapTarget,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outline),
                  boxShadow: DonyShadow.sm,
                ),
                child: RotatedBox(
                  quarterTurns: 1,
                  child: DonyIcon(
                    'arrow-left-right',
                    size: 17,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aller | Retour côte à côte (Aller seul en aller simple).
class _DatesRow extends StatelessWidget {
  const _DatesRow({required this.query, required this.onTap});

  final FlightSearchQuery query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final style = _valueStyle(context)?.copyWith(
      color: cs.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget cell(Key key, String label, String value, {Color? color}) =>
        Semantics(
          button: true,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(label),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        );

    return Container(
      margin: const EdgeInsetsDirectional.only(start: DonySpacing.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: cell(
                const Key('flights-departure-date'),
                l.flightsOutboundLabel,
                FlightFormat.when(l, query.departure),
              ),
            ),
            if (query.roundTrip) ...[
              VerticalDivider(width: 1, thickness: 1, color: cs.outline),
              const SizedBox(width: DonySpacing.md + DonySpacing.xxs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: DonySpacing.lg,
                  ),
                  child: cell(
                    const Key('flights-return-date'),
                    l.flightsReturnLabel,
                    query.returnDate == null
                        ? l.flightsFieldChooseDates
                        : FlightFormat.when(l, query.returnDate),
                    color: query.returnDate == null ? cs.primary : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
