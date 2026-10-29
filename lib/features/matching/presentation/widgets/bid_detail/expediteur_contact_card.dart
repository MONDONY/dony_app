import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/profil_card_widgets.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Carte profil expéditeur (vue voyageur) : un bouton « Contacter » (icône
/// conversation) qui ouvre la discussion. L'appel se lance depuis la
/// messagerie, pas depuis cette carte.
///
/// Affichée à tous les statuts : tant que la demande est en attente, seul le
/// profil est visible, sans bouton de contact ([bidAllowsContact]), avec un
/// indice qui dit quand le contact deviendra possible.
///
/// Le bouton n'apparaît qu'une fois la demande acceptée ([bidAllowsContact]) ou
/// pendant la fenêtre de contact d'un colis annulé ou en retour
/// ([bidAllowsContactFor]).
///
/// Requiert un [ConversationOpenBloc] dans le contexte.
class ExpediteurContactCard extends StatelessWidget {
  final BidModel bid;

  const ExpediteurContactCard({super.key, required this.bid});

  /// Bouton rond « Contacter » (icône conversation) : il dit qu'on peut parler
  /// à l'expéditeur et ouvre la discussion.
  Widget _contactButton(BuildContext context) {
    return BlocBuilder<ConversationOpenBloc, ConversationOpenState>(
      builder: (context, openState) {
        final busy = openState is ConversationOpenLoading;
        return _IconActionButton(
          iconAsset: 'messages-square',
          semanticLabel: context.l10n.bidDetailContactSenderLabel,
          isLoading: busy,
          onTap: busy ? null : () => _openChat(context),
        );
      },
    );
  }

  void _openChat(BuildContext context) => context
      .read<ConversationOpenBloc>()
      .add(ConversationOpenRequested(bid.id));

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final name = bid.senderDisplayName(l);
    // Retour en cours d'un colis annulé : contact rouvert (FLUTTER-FM).
    final returnInProgress = bidReturnInProgress(bid);
    // Commande annulée : le serveur garde le contact 48 h (FLUTTER-P1).
    final cancelledWindow = bidCancelledContactOpen(bid);
    final contactAllowed = bidAllowsContactFor(bid);
    final canOpenProfile = bid.senderId.isNotEmpty;

    return InkWell(
      onTap: canOpenProfile
          ? () => context.push(
              '/profile/public',
              extra: ProfilePublicArgs(userId: bid.senderId),
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
              l.bidSenderRoleTag,
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
                  imageUrl: bid.senderAvatarUrl,
                  verified: bid.senderKycVerified,
                  pro: bid.senderIsProAccount,
                  gpPro: bid.senderGpPro,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom + badges — Wrap : un nom long + deux badges (KYC +
                      // GP Pro) ne tiennent pas sur une ligne dans la colonne
                      // étroite ; le Wrap fait passer les chips à la ligne au
                      // lieu d'un RenderFlex overflow. Le nom (maxLines 1 +
                      // ellipsis) est borné par la largeur du Wrap.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: DonySpacing.xs,
                        runSpacing: DonySpacing.xs,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (bid.senderKycVerified)
                            MiniChip(
                              label: l.listingIdentityBadge,
                              color: cs.primary,
                              bg: cs.primaryContainer,
                            ),
                          if (bid.senderGpPro)
                            const GpProBadge(
                              surface: 'sender_contact',
                              interactive: false,
                            ),
                        ],
                      ),
                      // Nombre d'envois
                      if (bid.senderTotalShipments != null)
                        Text(
                          '· ${senderShipmentsCount(l, bid.senderTotalShipments!)}',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (contactAllowed) _contactButton(context),
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
            if (returnInProgress) ...[
              const SizedBox(height: DonySpacing.sm),
              Row(
                key: const Key('contact-return-in-progress-hint'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyIcon('package', size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      l.bidDetailReturnContactTravelerHint,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (cancelledWindow) ...[
              const SizedBox(height: DonySpacing.sm),
              Row(
                key: const Key('contact-cancelled-window-hint'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyIcon('clock', size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      l.bidDetailCancelledContactWindowHint,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (!contactAllowed &&
                bidContactPendingStatuses.contains(bid.status)) ...[
              const SizedBox(height: DonySpacing.sm),
              Row(
                key: const Key('contact-after-acceptance-hint'),
                children: [
                  DonyIcon('lock', size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      bid.status == 'AWAITING_PAYMENT'
                          ? l.bidDetailContactSenderAfterPaymentHint
                          : l.bidDetailContactSenderAfterAcceptanceHint,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bouton icône circulaire 44×44 ─────────────────────────────────────────────

class _IconActionButton extends StatelessWidget {
  final String iconAsset;
  final VoidCallback? onTap;
  final bool isLoading;

  /// Nom annoncé. Le bouton n'affiche qu'une icône : sans lui, un lecteur
  /// d'écran dit « bouton » et rien de plus.
  final String semanticLabel;

  const _IconActionButton({
    required this.iconAsset,
    required this.onTap,
    required this.semanticLabel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      enabled: onTap != null,
      label: semanticLabel,
      // `excludeSemantics` retire l'action du `GestureDetector` enfant : sans
      // `onTap` ici, un lecteur d'écran annonce « bouton » sans pouvoir
      // l'activer.
      onTap: onTap,
      child: GestureDetector(
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
              : DonyIcon(iconAsset, color: cs.primary, size: 18),
        ),
      ),
    );
  }
}
