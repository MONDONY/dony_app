import 'package:dony/core/constants/city_airport_codes.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/billet_perforation.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Partie « trajet » d'un billet Yadony : corridor départ → arrivée (codes en
/// grand, villes en clair), dates de départ et d'arrivée, puis la ligne de
/// perforation.
///
/// Partagée par le billet du détail de colis (`ColisBillet`) et la fiche
/// trajet vue par un expéditeur (FLUTTER-GG). Ne dépend d'aucun modèle : chaque
/// appelant lui passe ses villes, dates et heures.
class BilletRoute extends StatelessWidget {
  const BilletRoute({
    super.key,
    required this.departureCity,
    required this.arrivalCity,
    this.departureDate,
    this.departureTime,
    this.arrivalDate,
    this.arrivalTime,
    this.showWeekday = false,
    this.notchColor,
  });

  final String departureCity;
  final String arrivalCity;
  final DateTime? departureDate;

  /// Heure au format `HH:mm` ou `HH:mm:ss` (tronquée à `HH:mm`).
  final String? departureTime;
  final DateTime? arrivalDate;
  final String? arrivalTime;

  /// Jour de la semaine devant la date (« lun. 5 oct. ») : utile pour choisir
  /// un trajet, superflu sur un colis déjà réservé.
  final bool showWeekday;

  /// Couleur des encoches : celle du fond derrière le billet. `null` : pas de
  /// perforation (l'appelant la pose lui-même).
  final Color? notchColor;

  @override
  Widget build(BuildContext context) {
    final notch = notchColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BilletCorridor(departureCity: departureCity, arrivalCity: arrivalCity),
        BilletDates(
          departureDate: departureDate,
          departureTime: departureTime,
          arrivalDate: arrivalDate,
          arrivalTime: arrivalTime,
          showWeekday: showWeekday,
        ),
        if (notch != null) BilletPerforation(notchColor: notch),
      ],
    );
  }
}

// ── Corridor départ → arrivée ──────────────────────────────────────────────────

/// Codes de ville en grand, nom complet dessous. Un nom long passe à la ligne,
/// jamais tronqué (Sentry FLUTTER-EY : « Fontenay-le-… »). Lu « départ →
/// arrivée » d'un seul tenant par le lecteur d'écran.
class BilletCorridor extends StatelessWidget {
  const BilletCorridor({
    super.key,
    required this.departureCity,
    required this.arrivalCity,
  });

  final String departureCity;
  final String arrivalCity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final codeStyle = tt.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 28,
      letterSpacing: -0.5,
      color: cs.onSurface,
    );
    final cityStyle = tt.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
      height: 1.25,
    );

    return Semantics(
      label: '$departureCity → $arrivalCity',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      cityAirportCode(departureCity, departure: true),
                      maxLines: 1,
                      style: codeStyle,
                    ),
                  ),
                  Text(
                    departureCity,
                    key: const Key('billet_departure_city'),
                    softWrap: true,
                    style: cityStyle,
                  ),
                ],
              ),
            ),
            // Ligne + avion, centrés sur les codes.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.sm,
                DonySpacing.md,
                DonySpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  _DashedLine(color: cs.outline),
                  const SizedBox(width: DonySpacing.xs),
                  DonyIcon('plane', size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: DonySpacing.xs),
                  _DashedLine(color: cs.outline),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      cityAirportCode(arrivalCity, departure: false),
                      maxLines: 1,
                      style: codeStyle,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Text(
                    arrivalCity,
                    key: const Key('billet_arrival_city'),
                    softWrap: true,
                    style: cityStyle,
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini ligne pointillée horizontale pour le corridor billet.
class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Row(
        children: List.generate(
          5,
          (i) => Expanded(
            child: Container(
              height: 1,
              color: i.isEven ? color : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Zone dates ─────────────────────────────────────────────────────────────────

/// Dates et heures de départ et d'arrivée. L'arrivée affiche sa date quand
/// elle tombe un autre jour que le départ (vol de nuit, FLUTTER-4E), l'heure
/// seule sinon. Une valeur inconnue s'affiche « - ».
class BilletDates extends StatelessWidget {
  const BilletDates({
    super.key,
    this.departureDate,
    this.departureTime,
    this.arrivalDate,
    this.arrivalTime,
    this.showWeekday = false,
  });

  final DateTime? departureDate;
  final String? departureTime;
  final DateTime? arrivalDate;
  final String? arrivalTime;
  final bool showWeekday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    final depDate = departureDate;
    final arrDate = arrivalDate;
    final arrivalOtherDay =
        arrDate != null &&
        (depDate == null || !DateUtils.isSameDay(arrDate, depDate));

    final departure = _join([
      if (depDate != null) _formatDate(depDate, l.localeName),
      _trimTime(departureTime),
    ]);
    final arrival = _join([
      if (arrivalOtherDay) _formatDate(arrDate, l.localeName),
      _trimTime(arrivalTime),
    ]);

    final labelStyle = tt.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = tt.bodySmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

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
                Text(l.ticketDepartureLabel, style: labelStyle),
                Text(
                  departure,
                  key: const Key('billet-departure-value'),
                  style: valueStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(l.ticketArrivalLabel, style: labelStyle),
                Text(
                  arrival,
                  key: const Key('billet-arrival-value'),
                  style: valueStyle,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _join(List<String?> parts) {
    final kept = parts.whereType<String>().toList();
    return kept.isEmpty ? '-' : kept.join(' · ');
  }

  /// Tronque « HH:mm:ss » en « HH:mm » ; `null` si l'heure est inconnue.
  static String? _trimTime(String? t) {
    if (t == null || t.isEmpty) return null;
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  /// Squelette `MMMd` (« 5 mars », « Mar 5 ») ou `MMMEd` avec le jour.
  String _formatDate(DateTime date, String locale) => showWeekday
      ? DateFormat.MMMEd(locale).format(date)
      : DateFormat.MMMd(locale).format(date);
}
