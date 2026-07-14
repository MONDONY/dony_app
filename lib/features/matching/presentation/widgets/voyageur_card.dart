import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/profil_card_widgets.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Carte profil voyageur affichée à l'expéditeur (statuts ACCEPTED → COMPLETED).
///
/// Ouvre le profil public via GoRouter au tap.
/// Requiert un [ConversationOpenBloc] dans le contexte.
class VoyageurCard extends StatelessWidget {
  final BidModel bid;

  const VoyageurCard({super.key, required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final name = bid.travelerName ?? 'Voyageur';
    final canOpenProfile = bid.travelerId != null;

    final ratingLabel = bid.travelerAverageRating != null
        ? '★ ${bid.travelerAverageRating!.toStringAsFixed(1)}'
        : '★ -';
    final tripsLabel = bid.travelerTotalTrips != null
        ? '· ${bid.travelerTotalTrips} trajet${bid.travelerTotalTrips! > 1 ? 's' : ''}'
        : '';

    return InkWell(
      onTap: canOpenProfile
          ? () => context.push(
                '/profile/public',
                extra: ProfilePublicArgs(
                  userId: bid.travelerId,
                  showSubscribe: true,
                ),
              )
          : null,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VOYAGEUR',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            Row(
              children: [
                DonyAvatar(
                  name: name,
                  imageUrl: bid.travelerAvatarUrl,
                  verified: bid.travelerKycVerified,
                  pro: bid.travelerIsProAccount,
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
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (bid.travelerKycVerified) ...[
                            const SizedBox(width: DonySpacing.xs),
                            MiniChip(
                              label: 'KYC',
                              color: cs.primary,
                              bg: cs.primaryContainer,
                            ),
                          ],
                          if (bid.travelerKiloPro) ...[
                            const SizedBox(width: DonySpacing.xs),
                            const MiniChip(
                              label: 'Kilo Pro',
                              color: DonyColors.amberDark,
                              bg: DonyColors.amberLight,
                            ),
                          ],
                        ],
                      ),
                      // Note + trajets
                      Text(
                        '$ratingLabel $tripsLabel'.trim(),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                _IconActionButton(iconAsset: 'phone', onTap: () {}),
                const SizedBox(width: DonySpacing.sm),
                BlocBuilder<ConversationOpenBloc, ConversationOpenState>(
                  builder: (context, openState) {
                    final isOpening = openState is ConversationOpenLoading;
                    return _IconActionButton(
                      iconAsset: 'message-circle',
                      isLoading: isOpening,
                      onTap: isOpening
                          ? null
                          : () => context.read<ConversationOpenBloc>().add(
                              ConversationOpenRequested(bid.id),
                            ),
                    );
                  },
                ),
                if (canOpenProfile) ...[
                  const SizedBox(width: DonySpacing.xs),
                  DonyIcon(
                    'chevron-right',
                    color: cs.onSurfaceVariant,
                    size: 18,
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

// ── Bouton icône circulaire (contact voyageur) ─────────────────────────────────

class _IconActionButton extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final VoidCallback? onTap;
  final bool isLoading;

  const _IconActionButton({
    required this.onTap,
    this.icon,
    this.iconAsset,
    this.isLoading = false,
  }) : assert(icon != null || iconAsset != null);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: cs.primary),
        ),
        child: isLoading
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  color: cs.primary,
                  strokeWidth: 2,
                ),
              )
            : iconAsset != null
                ? DonyIcon(iconAsset!, color: cs.primary, size: 18)
                : Icon(icon, color: cs.primary, size: 18),
      ),
    );
  }
}
