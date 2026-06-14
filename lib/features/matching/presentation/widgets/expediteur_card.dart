import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/profil_card_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte profil expéditeur affichée au voyageur.
///
/// Tappable si [onTap] est fourni — ouvre généralement le profil public.
class ExpediteurCard extends StatelessWidget {
  final BidModel bid;
  final VoidCallback? onTap;

  const ExpediteurCard({super.key, required this.bid, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expéditeur',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            Row(
              children: [
                DonyAvatar(
                  name: bid.resolvedSenderName,
                  imageUrl: bid.senderAvatarUrl,
                  verified: bid.senderKycVerified,
                  pro: bid.senderIsProAccount,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom + badges
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              bid.resolvedSenderName,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          if (bid.senderKycVerified) ...[
                            const SizedBox(width: DonySpacing.xs),
                            MiniChip(
                              label: 'KYC',
                              color: cs.primary,
                              bg: cs.primaryContainer,
                            ),
                          ],
                          if (bid.senderKiloPro) ...[
                            const SizedBox(width: DonySpacing.xs),
                            const MiniChip(
                              label: 'Kilo Pro',
                              color: DonyColors.amberDark,
                              bg: DonyColors.amberLight,
                            ),
                          ],
                        ],
                      ),
                      if (bid.senderPhone != null)
                        Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              bid.senderPhone!,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      if (bid.senderTotalShipments != null)
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping_rounded,
                              size: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              '${bid.senderTotalShipments} envoi${(bid.senderTotalShipments ?? 0) > 1 ? 's' : ''}',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      Text(
                        'Soumis le ${DateFormat('dd/MM/yyyy').format(bid.createdAt.toLocal())}',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: DonySpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
