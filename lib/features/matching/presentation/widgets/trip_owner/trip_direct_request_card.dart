import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcel_rows.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// « contenu · poids » d'une demande ([tripParcelContent], comme la ligne
/// d'un colis du sheet « Colis ») ; poids omis s'il n'est pas connu.
String tripRequestDetails(AppLocalizations l, BidModel bid) {
  final content = tripParcelContent(l, bid);
  final w = bid.displayWeightKg;
  if (w == null) return content;
  return '$content · ${w.toStringAsFixed(w % 1 == 0 ? 0 : 1)} kg';
}

/// Carte « réponse directe » de « À traiter » sur l'écran du trajet vu par
/// son voyageur : la première demande à traiter (ordre reçu,
/// [tripRequestsToAnswer]), avec Refuser et Accepter, puis « Voir les N
/// demandes » quand il y en a plusieurs ([onSeeAll], qui ouvre le sheet des
/// demandes).
///
/// Répondre passe par le [TripBidAnswerScope] posé au-dessus : boutons
/// éteints et chargement pendant l'appel ; une fois la réponse confirmée, la
/// carte passe à la demande suivante, et disparaît après la dernière. Une
/// erreur laisse la demande en place.
///
/// Ne rend rien quand aucune demande n'est à traiter, ou tant que la liste
/// des colis n'a pas répondu ([bids] `null`) : il n'y a pas de demande à
/// montrer. C'est la grosse carte de « À traiter » quand les demandes sont
/// l'action la plus urgente (`TripTodoSection`), qui en mesure l'affichage
/// (`bid_detail_todo_tile_shown`, action `requests`).
class TripDirectRequestCard extends StatelessWidget {
  const TripDirectRequestCard({
    super.key,
    required this.bids,
    required this.onSeeAll,
  });

  /// Colis chargés par l'écran (`BidListLoaded`), `null` tant que la liste
  /// n'a pas répondu.
  final List<BidModel>? bids;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final controller = TripBidAnswerScope.of(context);
    return ValueListenableBuilder<Set<String>>(
      valueListenable: controller.answered,
      builder: (context, answered, _) {
        final pending = tripRequestsToAnswer(bids, answered) ?? const [];
        if (pending.isEmpty) return const SizedBox.shrink();
        final l = context.l10n;
        final bid = pending.first;
        return DetailCard(
          key: const Key('trip-direct-request-card'),
          title: l.tripDirectRequestLabel(pending.length),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TripRequestIdentity(
                key: Key('trip-direct-request-${bid.id}'),
                bid: bid,
              ),
              const SizedBox(height: DonySpacing.md),
              TripRequestAnswerButtons(bid: bid),
              if (pending.length > 1) ...[
                const SizedBox(height: DonySpacing.xs),
                Center(
                  child: TextButton(
                    key: const Key('trip-direct-request-see-all'),
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      textStyle: Theme.of(context).textTheme.labelLarge,
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(
                      l.tripDirectRequestSeeAll(pending.length),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Qui envoie et quoi : avatar (initiales), nom de l'expéditeur, « contenu
/// · poids », et le montant net du voyageur ([travelerNetAmount], formaté
/// comme la liste des demandes). Lue d'un seul tenant par le lecteur
/// d'écran.
class TripRequestIdentity extends StatelessWidget {
  const TripRequestIdentity({super.key, required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = bid.senderDisplayName(l);
    final net = travelerNetAmount(bid);
    return MergeSemantics(
      child: Row(
        children: [
          DonyAvatar(name: name, imageUrl: bid.senderAvatarUrl),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tripRequestDetails(l, bid),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (net != null) ...[
            const SizedBox(width: DonySpacing.sm),
            Text(
              formatPriceIn(net, bid.currency),
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// « Refuser » | « Accepter » d'une demande, sur une ligne à parts égales,
/// comme la barre de réponse de la fiche colis (Refuser en texte rouge,
/// Accepter plein vert). Répond par le [TripBidAnswerScope] au-dessus : tous
/// les boutons sont éteints pendant une réponse, celui de la demande en
/// cours tourne.
///
/// Acceptation refusée pour de bon ([TripBidAnswerController.refused] :
/// trajet complet, fermé…) : le motif du serveur s'affiche au-dessus des
/// boutons et « Accepter » reste éteint, comme dans la liste des demandes
/// (`DemandesScreen`) ; « Refuser » reste possible.
class TripRequestAnswerButtons extends StatelessWidget {
  const TripRequestAnswerButtons({super.key, required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = TripBidAnswerScope.of(context);
    return ValueListenableBuilder<Map<String, AppException>>(
      valueListenable: controller.refused,
      builder: (context, refused, _) {
        final refusal = refused[bid.id];
        return ValueListenableBuilder<TripBidAnswering?>(
          valueListenable: controller.answering,
          builder: (context, answering, _) {
            final busy = answering != null;
            bool spinning(TripBidAnswerAction action) =>
                answering?.bidId == bid.id && answering?.action == action;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (refusal != null) ...[
                  _RefusalNote(
                    key: Key('trip-request-refused-${bid.id}'),
                    message: ErrorCatalog.lookup(refusal, l10n: l).message,
                  ),
                  const SizedBox(height: DonySpacing.sm),
                ],
                Row(
                  children: [
                    Expanded(
                      child: DonyButton(
                        key: Key('trip-request-reject-${bid.id}'),
                        label: l.bidDetailDeclineRequestButton,
                        variant: DonyButtonVariant.destructiveGhost,
                        isLoading: spinning(TripBidAnswerAction.reject),
                        onPressed: busy
                            ? null
                            : () => controller.reject(bid, from: context),
                      ),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: DonyButton(
                        key: Key('trip-request-accept-${bid.id}'),
                        label: l.bidDetailAcceptRequestButton,
                        variant: DonyButtonVariant.success,
                        isLoading: spinning(TripBidAnswerAction.accept),
                        onPressed: busy || refusal != null
                            ? null
                            : () => controller.accept(bid, from: context),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Motif d'un refus définitif de l'acceptation, au style de celui de la
/// liste des demandes (bandeau d'alerte discret).
class _RefusalNote extends StatelessWidget {
  const _RefusalNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        children: [
          DonyIcon('circle-alert', size: 14, color: cs.warning),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              message,
              style: tt.labelMedium?.copyWith(color: cs.warning),
            ),
          ),
        ],
      ),
    );
  }
}
