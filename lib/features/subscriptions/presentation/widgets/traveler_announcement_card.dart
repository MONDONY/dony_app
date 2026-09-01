import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Trajet d'un voyageur, dans sa fiche.
///
/// La carte est volontairement typographique : le corridor, la date et le prix
/// portent seuls l'information. La version précédente y ajoutait un rail
/// pointillé, un avion et un liseré dégradé sur le bord — un décor de carte
/// d'embarquement qui n'encodait rien et écrasait le contenu réel.
class TravelerAnnouncementCard extends StatelessWidget {
  const TravelerAnnouncementCard({
    super.key,
    required this.announcement,
    required this.onReserve,
  });

  final TravelerAnnouncement announcement;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isFull = announcement.availableKg <= 0;

    return DonyCard(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Corridor(
            from: announcement.departureCity,
            to: announcement.arrivalCity,
          ),
          const SizedBox(height: DonySpacing.sm),
          _MetaLine(announcement: announcement, isFull: isFull),
          const SizedBox(height: DonySpacing.base),
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        formatPriceIn(
                          netToSenderPrice(announcement.pricePerKg),
                          announcement.currency,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: DonySpacing.xxs),
                    Text(
                      '/kg',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              // Bouton à contour plutôt que plein : sur une fiche qui ne
              // présente qu'un ou deux trajets, un aplat de couleur par carte
              // criait plus fort que le prix qu'il accompagne.
              OutlinedButton(
                onPressed: isFull ? null : onReserve,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.outline),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.lg),
                  ),
                  minimumSize: const Size(0, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Réserver'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Corridor « Ville → Ville ».
///
/// Chaque ville s'abrège de son côté plutôt que de pousser l'autre hors du
/// cadre : « Marseille → Abidjan » doit rester lisible des deux bouts.
class _Corridor extends StatelessWidget {
  const _Corridor({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final style = tt.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.15,
    );

    return Row(
      children: [
        Flexible(
          child: Text(
            from,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
          child: Text(
            '→',
            style: style?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Flexible(
          child: Text(
            to,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.announcement, required this.isFull});

  final TravelerAnnouncement announcement;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final style = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    return Row(
      children: [
        DonyIcon('calendar', size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        Flexible(
          child: Text(
            DateFormat('d MMM yyyy', 'fr').format(announcement.departureDate),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(' · ', style: style),
        Text(
          isFull
              ? 'Complet'
              : '${announcement.availableKg.toStringAsFixed(0)} kg disponibles',
          style: isFull
              ? style?.copyWith(color: cs.error, fontWeight: FontWeight.w700)
              : style,
        ),
      ],
    );
  }
}
