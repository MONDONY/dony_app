import 'package:dony/core/constants/city_airport_codes.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/matching/presentation/widgets/billet_perforation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Carte billet de colis complète (boarding-pass metaphor).
///
/// Assemble l'en-tête DONY, le corridor départ→arrivée, la zone dates,
/// la ligne de perforation et le talon d'action.
///
/// NOTE sur le format de date : [DateFormat] avec locale 'fr' nécessite que
/// les données de locale soient initialisées
/// ([intl.initializeDateFormatting]). Si elles ne le sont pas (ex : tests
/// unitaires isolés), le widget retombe sur un format numérique
/// non-localisé ("MM/dd") qui ne lève aucune exception.
class ColisBillet extends StatelessWidget {
  final BidModel bid;
  final bool isSender;

  const ColisBillet({super.key, required this.bid, required this.isSender});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            boxShadow: DonyShadow.md,
          ),
          // overflow visible pour que les encoches de BilletPerforation mordent
          // dans les bords latéraux sans être clippées.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BilletHeader(bid: bid),
              _BilletCorridor(bid: bid),
              _BilletDates(bid: bid),
              BilletPerforation(
                notchColor: Theme.of(context).scaffoldBackgroundColor,
              ),
              BilletTalon(bid: bid, isSender: isSender),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ── En-tête ────────────────────────────────────────────────────────────────────

class _BilletHeader extends StatelessWidget {
  final BidModel bid;
  const _BilletHeader({required this.bid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.base,
        DonySpacing.base,
        DonySpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'DONY · TRANSPORT DE COLIS',
              style: tt.bodySmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          BilletStatusStamp(status: bid.status),
        ],
      ),
    );
  }
}

// ── Corridor départ → arrivée ──────────────────────────────────────────────────

class _BilletCorridor extends StatelessWidget {
  final BidModel bid;
  const _BilletCorridor({required this.bid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final depCity = bid.departureCity ?? 'Paris';
    final arrCity = bid.arrivalCity ?? 'Dakar';
    final depCode = cityAirportCode(depCity, departure: true);
    final arrCode = cityAirportCode(arrCity, departure: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
      child: Row(
        children: [
          // Départ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    depCode,
                    maxLines: 1,
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: -0.5,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  depCity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Ligne + icône avion
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
            child: Row(
              children: [
                _DashedLine(color: cs.outline),
                const SizedBox(width: DonySpacing.xs),
                DonyIcon(
                  'plane',
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: DonySpacing.xs),
                _DashedLine(color: cs.outline),
              ],
            ),
          ),
          // Arrivée
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    arrCode,
                    maxLines: 1,
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: -0.5,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
                Text(
                  arrCity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini ligne pointillée horizontale pour le corridor billet.
class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
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

class _BilletDates extends StatelessWidget {
  final BidModel bid;
  const _BilletDates({required this.bid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final dateStr = _formatDate(bid.departureDate);
    final depTime = _trimTime(bid.departureTime);
    final arrTime = _trimTime(bid.arrivalTime);

    final labelStyle = tt.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = tt.bodySmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.sm,
        DonySpacing.base,
        DonySpacing.base,
      ),
      child: Row(
        children: [
          // Départ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Départ', style: labelStyle),
                Text(
                  dateStr != null ? '$dateStr · $depTime' : depTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          // Arrivée
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Arrivée', style: labelStyle),
                Text(
                  arrTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tronque un time string "HH:mm:ss" en "HH:mm".
  String _trimTime(String? t) {
    if (t == null || t.isEmpty) return '-';
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  /// Formate [date] en "d MMM" avec locale 'fr'.
  /// Si les données de locale ne sont pas initialisées, retombe sur "d/M"
  /// (locale-independent) pour éviter une [LocaleDataException] en test.
  String? _formatDate(DateTime? date) {
    if (date == null) {
      return null;
    }
    try {
      return DateFormat('d MMM', 'fr').format(date);
    } catch (_) {
      // Locale data not initialized — use numeric fallback.
      return DateFormat('d/M').format(date);
    }
  }
}
