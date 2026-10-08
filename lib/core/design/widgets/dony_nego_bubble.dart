import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Bulle d'un message d'un fil de négociation (maquettes v3).
///
/// - `mine = true`  → fond primary plein, texte blanc, coin bas droit cassé ;
/// - `mine = false` → fond surface bordé, texte sombre, coin bas gauche cassé.
///
/// Partagée par les fils de prix « demande de colis » et « trajet ». Elle ne
/// reçoit que des textes déjà prêts : le montant (net ou brut selon le rôle)
/// est choisi par l'appelant, jamais ici.
class DonyNegoBubble extends StatelessWidget {
  const DonyNegoBubble({
    super.key,
    required this.kindLabel,
    required this.mine,
    this.priceText,
    this.body,
    this.sentAt,
    this.highlight = false,
  });

  /// Libellé en capitales (PROPOSITION, CONTRE-OFFRE…).
  final String kindLabel;
  final bool mine;
  final String? priceText;
  final String? body;

  /// Heure affichée sous le message. Absente : ligne omise.
  final DateTime? sentAt;

  /// Cadre ambré et pastille « NOUVEAU » : dernière offre reçue, à traiter.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );
    final bg = mine ? DonyColors.primary : cs.surface;
    final textColor = mine ? Colors.white : cs.onSurface;
    final labelColor = mine
        ? Colors.white.withValues(alpha: 0.85)
        : cs.onSurfaceVariant;
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
                        color: highlight ? DonyColors.warning : cs.outline,
                        width: highlight ? 1.5 : 1,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kindLabel,
                    style: tt.bodyMedium!.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (priceText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      priceText!,
                      style: tt.bodyMedium!.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: priceColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                  if (body != null && body!.isNotEmpty) ...[
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      body!,
                      style: tt.bodyMedium!.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (sentAt != null) ...[
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      DateFormat.jm(context.l10n.localeName).format(sentAt!),
                      style: tt.bodyMedium!.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: mine
                            ? Colors.white.withValues(alpha: 0.65)
                            : DonyColors.neutral400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (highlight && !mine)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: DonyColors.warning,
                    borderRadius: BorderRadius.circular(DonyRadius.xl),
                  ),
                  child: Text(
                    context.l10n.negotiationMessageNewBadge,
                    style: tt.bodyMedium!.copyWith(
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
}
