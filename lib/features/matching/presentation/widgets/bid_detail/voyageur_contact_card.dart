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

/// Carte profil voyageur (vue expéditeur) — un bouton « Contacter » (icône
/// conversation) : discussion directe, ou feuille appel / message quand
/// l'appel est possible.
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

  /// Bouton rond « Contacter » (icône conversation) : il porte l'idée qu'on
  /// peut parler au voyageur, sans choisir le moyen à la place de l'utilisateur.
  Widget _contactButton(
    BuildContext context, {
    required bool canCall,
    bool isRevealing = false,
  }) {
    return BlocBuilder<ConversationOpenBloc, ConversationOpenState>(
      builder: (context, openState) {
        final busy = isRevealing || openState is ConversationOpenLoading;
        return _IconActionButton(
          iconAsset: 'messages-square',
          semanticLabel: context.l10n.bidDetailContactTravelerLabel,
          isLoading: busy,
          onTap: busy
              ? null
              : () => canCall ? _showContactSheet(context) : _openChat(context),
        );
      },
    );
  }

  void _openChat(BuildContext context) => context
      .read<ConversationOpenBloc>()
      .add(ConversationOpenRequested(bid.id));

  /// Feuille « Contacter le voyageur » : écrire ou appeler. Les deux blocs
  /// sont lus ici, avant l'ouverture : la feuille vit sur le navigateur racine,
  /// hors des fournisseurs de l'écran.
  void _showContactSheet(BuildContext context) {
    final l = context.l10n;
    DonyBottomSheet.show<void>(
      context,
      title: l.bidDetailContactTravelerLabel,
      child: Builder(
        builder: (sheetContext) => Column(
          children: [
            _ContactOption(
              iconAsset: 'message-circle',
              label: l.voyageurCardContactChat,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openChat(context);
              },
            ),
            const SizedBox(height: DonySpacing.sm),
            _ContactOption(
              iconAsset: 'phone',
              label: l.travelerContactCall,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _requestCall(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final name = bid.travelerName ?? l.tripTravelerFallbackName;
    // Retour en cours d'un colis annulé : contact rouvert (FLUTTER-FM).
    final returnInProgress = bidReturnInProgress(bid);
    // Commande annulée : le serveur garde le contact 48 h (FLUTTER-P1).
    final cancelledWindow = bidCancelledContactOpen(bid);
    final contactAllowed = bidAllowsContactFor(bid);
    final canOpenProfile = bid.travelerId != null;
    final canCall = _showPhoneButton && contactAllowed;

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
                  gpPro: bid.travelerGpPro,
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
                          if (bid.travelerKycVerified)
                            MiniChip(
                              label: l.listingIdentityBadge,
                              color: cs.primary,
                              bg: cs.primaryContainer,
                            ),
                          if (bid.travelerGpPro)
                            const GpProBadge(
                              surface: 'traveler_contact',
                              interactive: false,
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
                // Un seul bouton « Contacter » : le détail du moyen (appel ou
                // message) vient ensuite, dans une feuille. Sans appel possible,
                // il ouvre directement la discussion.
                if (contactAllowed)
                  canCall
                      ? BlocConsumer<ContactRevealBloc, ContactRevealState>(
                          listener: (context, state) {
                            if (state is ContactRevealSuccess) {
                              unawaited(
                                dialPhoneNumber(context, state.phoneNumber),
                              );
                            } else if (state is ContactRevealError) {
                              ErrorPresenter.show(context, state.error);
                            }
                          },
                          builder: (context, revealState) => _contactButton(
                            context,
                            canCall: true,
                            isRevealing: revealState is ContactRevealLoading,
                          ),
                        )
                      : _contactButton(context, canCall: false),
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

// ── Ligne de la feuille « Contacter » ─────────────────────────────────────────

class _ContactOption extends StatelessWidget {
  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  const _ContactOption({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.lg),
      child: Container(
        constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.sm),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.sm),
              ),
              child: DonyIcon(iconAsset, color: cs.primary, size: 18),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                label,
                style: tt.titleSmall?.copyWith(color: cs.onSurface),
              ),
            ),
            DonyIcon('chevron-right', color: cs.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}
