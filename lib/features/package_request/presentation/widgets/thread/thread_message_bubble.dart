import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Bulle d'un message du thread de négociation.
///
/// Match maquettes v3 `20-44-27`, `20-44-40`, `20-44-48` :
/// - `mine = true`  → fond primary blue solide, texte blanc, coin BR cassé
/// - `mine = false` → fond surface (card avec border outline), texte sombre,
///   coin BL cassé. Si `kind == proposal` venant de l'autre partie avec un
///   prix : badge "NOUVEAU" overlay top-right (rendu côté écran via flag).
///
/// Affiche : label CAPS (PROPOSITION / CONTRE-OFFRE / ACCEPTÉ / REJETÉ) +
/// prix prominent + body optionnel italique + timestamp HH:mm.
class ThreadMessageBubble extends StatelessWidget {
  const ThreadMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.highlight = false,
    required this.isTraveler,
    this.grossPriceEur,
  });

  final NegotiationMessage message;
  final bool mine;

  /// Affiche un cadre coloré "NOUVEAU" autour de la bulle (cas dernière
  /// proposition reçue côté sender quand pas encore lue).
  final bool highlight;

  /// Whether the current viewer is the traveler.
  /// - Traveler sees "Tu reçois X €" (net)
  /// - Sender sees "Tu paies X €" (gross)
  final bool isTraveler;

  /// Pre-computed gross price from the server. When null, gross is derived
  /// from the net using [PriceDisplay.grossFromNet].
  final double? grossPriceEur;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );
    final bg = mine ? DonyColors.primary : cs.surface;
    final textColor = mine ? Colors.white : cs.onSurface;
    final labelColor =
        mine ? Colors.white.withValues(alpha: 0.85) : cs.onSurfaceVariant;
    final priceColor = mine ? Colors.white : cs.primary;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: radius,
                border: mine
                    ? null
                    : Border.all(
                        color: highlight
                            ? DonyColors.warning
                            : cs.outline,
                        width: highlight ? 1.5 : 1,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _kindLabel(message.kind),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (message.proposedPriceEur != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      PriceDisplay.threadPriceLabel(
                        message.proposedPriceEur!,
                        grossPriceEur,
                        isTraveler,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: priceColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                  if (message.body != null && message.body!.isNotEmpty) ...[
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      message.body!,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.65)
                          : kTextHint,
                    ),
                  ),
                ],
              ),
            ),
            if (highlight && !mine)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: DonyColors.warning,
                    borderRadius: BorderRadius.circular(DonyRadius.xl),
                  ),
                  child: Text(
                    'NOUVEAU',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(NegotiationMessageKind k) => switch (k) {
        NegotiationMessageKind.proposal => 'PROPOSITION',
        NegotiationMessageKind.counter => 'CONTRE-OFFRE',
        NegotiationMessageKind.accept => 'ACCEPTÉE',
        NegotiationMessageKind.reject => 'REJETÉE',
      };
}
