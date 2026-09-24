import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/profil_card_widgets.dart';
import 'package:dony/l10n/l10n.dart';
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
    final l = context.l10n;
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
              // Même texte que le nom de repli (bidSenderFallbackName) :
              // même clé, la règle « même texte, même clé dans la feature ».
              l.bidSenderFallbackName,
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            Row(
              children: [
                DonyAvatar(
                  name: bid.senderDisplayName(l),
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
                              bid.senderDisplayName(l),
                              maxLines: 1,
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
                              label: l.listingIdentityBadge,
                              color: cs.primary,
                              bg: cs.primaryContainer,
                            ),
                          ],
                          if (bid.senderKiloPro) ...[
                            const SizedBox(width: DonySpacing.xs),
                            MiniChip(
                              label: l.listingKiloProChip,
                              color: DonyColors.amberDark,
                              bg: DonyColors.amberLight,
                            ),
                          ],
                        ],
                      ),
                      if (bid.senderTotalShipments != null)
                        Row(
                          children: [
                            const DonyEmoji.parcel(size: 12),
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              senderShipmentsCount(
                                l,
                                bid.senderTotalShipments!,
                              ),
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      Text(
                        l.bidSubmittedOn(
                          DateFormat.yMd(
                            l.localeName,
                          ).format(bid.createdAt.toLocal()),
                        ),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: DonySpacing.xs),
                  DonyIcon(
                    'chevron-right',
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
