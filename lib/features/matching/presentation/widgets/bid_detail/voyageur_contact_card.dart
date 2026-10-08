import 'dart:async';

import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/phone_dialer.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
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

/// Carte profil voyageur (vue expéditeur) — bouton 📞 conditionnel + 💬 chat.
///
/// Affichée à tous les statuts : tant que la demande est en attente, seul le
/// profil est visible, sans bouton d'appel ni de message
/// ([bidAllowsContact]).
///
/// Le bouton téléphone est affiché uniquement si :
///   - `bid.travelerPhoneAvailable` est vrai (le serveur autorise la révélation),
///   - ET la fenêtre de contact est ouverte : `bid.contactWindowOpen` du
///     serveur (ACCEPTED → ARRIVED, puis COMPLETED jusqu'à J+3 après la
///     livraison, même règle que l'appel in-app). Back antérieur sans ce
///     champ : repli sur le statut, ni COMPLETED ni DELIVERED.
///
/// Requiert un [ConversationOpenBloc] dans le contexte.
class VoyageurContactCard extends StatelessWidget {
  final BidModel bid;

  const VoyageurContactCard({super.key, required this.bid});

  /// Le serveur dit si le voyageur est joignable ; le numéro lui-même est
  /// demandé au tap. La fenêtre de contact vient du serveur ; à défaut (ancien
  /// back), on masque le bouton en fin de course.
  bool get _showPhoneButton {
    if (!bid.travelerPhoneAvailable || !smsAuthEnabledListenable.value) {
      return false;
    }
    final open = bid.contactWindowOpen;
    if (open != null) return open;
    final s = bid.status;
    return s != 'COMPLETED' && s != 'DELIVERED';
  }

  void _requestCall(BuildContext context) {
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.travelerCallInitiated,
        properties: {'status': bid.status},
      ),
    );
    context.read<ContactRevealBloc>().add(ContactRevealRequested(bid.id));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final name = bid.travelerName ?? l.tripTravelerFallbackName;
    // Retour en cours d'un colis annulé : contact rouvert (FLUTTER-FM).
    final returnInProgress = bidReturnInProgress(bid);
    final contactAllowed = bidAllowsContact(bid.status) || returnInProgress;
    final canOpenProfile = bid.travelerId != null;

    final ratingLabel = bid.travelerAverageRating != null
        ? '★ ${bid.travelerAverageRating!.toStringAsFixed(1)}'
        : '★ -';
    final tripsLabel = bid.travelerTotalTrips != null
        ? '· ${travelerTripsCount(l, bid.travelerTotalTrips!)}'
        : '';

    return InkWell(
      onTap: canOpenProfile
          ? () => context.push(
              '/profile/public',
              extra: ProfilePublicArgs(userId: bid.travelerId),
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
              l.bidTravelerRoleTag,
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
                      // Nom + badges — Wrap : un nom long + deux badges (KYC +
                      // Kilo Pro) ne tiennent pas sur une ligne dans la colonne
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
                          if (bid.travelerKycVerified)
                            MiniChip(
                              label: l.listingIdentityBadge,
                              color: cs.primary,
                              bg: cs.primaryContainer,
                            ),
                          if (bid.travelerKiloPro)
                            MiniChip(
                              label: l.listingKiloProChip,
                              color: DonyColors.amberDark,
                              bg: DonyColors.amberLight,
                            ),
                        ],
                      ),
                      // Note + trajets
                      Text(
                        '$ratingLabel $tripsLabel'.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bouton 📞 — conditionnel
                if (_showPhoneButton && contactAllowed) ...[
                  BlocConsumer<ContactRevealBloc, ContactRevealState>(
                    listener: (context, state) {
                      if (state is ContactRevealSuccess) {
                        unawaited(dialPhoneNumber(context, state.phoneNumber));
                      } else if (state is ContactRevealError) {
                        ErrorPresenter.show(context, state.error);
                      }
                    },
                    builder: (context, state) {
                      final isRevealing = state is ContactRevealLoading;
                      return _IconActionButton(
                        iconAsset: 'phone',
                        semanticLabel: l.voyageurCardCallSemanticLabel,
                        isLoading: isRevealing,
                        onTap: isRevealing ? null : () => _requestCall(context),
                      );
                    },
                  ),
                  const SizedBox(width: DonySpacing.sm),
                ],
                // Bouton 💬 chat
                if (contactAllowed)
                  BlocBuilder<ConversationOpenBloc, ConversationOpenState>(
                    builder: (context, openState) {
                      final isOpening = openState is ConversationOpenLoading;
                      return _IconActionButton(
                        iconAsset: 'message-circle',
                        semanticLabel: l.voyageurCardOpenChatSemanticLabel,
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
                      l.bidDetailReturnContactSenderHint,
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
                          ? l.bidDetailContactTravelerAfterPaymentHint
                          : l.bidDetailContactTravelerAfterAcceptanceHint,
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
