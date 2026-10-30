import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Nombre de colis montrés en ligne par la carte « Colis dans le trajet » :
/// au-delà, « Voir les N autres colis » ouvre la liste complète (un trajet de
/// dix colis rendait l'écran trop long).
const kTripParcelsPreviewCount = 2;

/// Statuts où le colis attend encore un geste du voyageur : à récupérer
/// (`ACCEPTED`), en route (`HANDED_OVER`, `IN_TRANSIT`), à remettre
/// (`ARRIVED`). Ce sont les segments « à récupérer », « en route » et
/// « arrivés » du résumé ([tripParcelsCounts]) ; un colis livré, clôturé ou
/// dont le paiement est attendu (`AWAITING_PAYMENT`, rien à aller chercher)
/// ne demande rien au voyageur.
const _kAwaitingTravelerStatuses = {
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
};

/// Les [kTripParcelsPreviewCount] colis montrés par la carte parmi
/// [embarked] : d'abord ceux qui attendent un geste du voyageur
/// ([_kAwaitingTravelerStatuses]), puis les autres ; l'ordre reçu est gardé
/// à l'intérieur de chaque groupe (tri stable).
List<BidModel> tripParcelsPreview(List<BidModel> embarked) => [
  ...embarked.where((b) => _kAwaitingTravelerStatuses.contains(b.status)),
  ...embarked.where((b) => !_kAwaitingTravelerStatuses.contains(b.status)),
].take(kTripParcelsPreviewCount).toList(growable: false);

/// Carte « Colis dans le trajet » de l'écran détail trajet (propriétaire),
/// carte du corps comme celles de la fiche colis ([DetailCard]).
///
/// Consomme le [BidBloc] fourni par la route (`BidListRequested(announcementId)`).
/// Le titre porte le total des colis embarqués (« Colis dans le trajet · 7 »).
/// Le résumé ([TripParcelsSummary]) compte tous les colis ; seules les
/// [kTripParcelsPreviewCount] premières lignes sont rendues
/// ([tripParcelsPreview]), suivies au-delà de « Voir les N autres colis ».
/// Ce bouton et le lien « Voir la liste » de l'en-tête (dès qu'un colis est
/// embarqué) ouvrent la liste des colis du trajet (`/announcements/:id/bids`) ;
/// une ligne ouvre la fiche du colis (`/bids/:id`). Au retour de l'une ou de
/// l'autre, les colis et le trajet sont relus ([openTripParcelsList],
/// [openTripParcel]). Liste en échec (`BidError`) : « Réessayer » la
/// redemande.
/// Filtre les offres réellement embarquées via [isAcceptedTabBid] (source de
/// vérité du projet : ACCEPTED / HANDED_OVER / IN_TRANSIT / ARRIVED / COMPLETED,
/// moins les
/// auto-annulés). Émet une fois l'event analytics `trip_parcels_viewed` au
/// premier chargement de la liste (total des colis embarqués, aucune PII).
class TripParcelsSection extends StatefulWidget {
  const TripParcelsSection({super.key, required this.announcementId});

  /// Trajet dont les colis sont affichés, relus au retour d'un écran ouvert
  /// depuis la carte.
  final String announcementId;

  @override
  State<TripParcelsSection> createState() => _TripParcelsSectionState();
}

class _TripParcelsSectionState extends State<TripParcelsSection> {
  /// Garde l'event analytics à un seul tir (pas à chaque rebuild). Mutée hors
  /// `setState` — elle ne déclenche aucun rendu, juste l'idempotence du log.
  bool _logged = false;

  void _logOnce(int count) {
    if (_logged) {
      return;
    }
    _logged = true;
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.tripParcelsViewed,
        properties: {'count': count},
      ),
    );
  }

  /// Liste complète des colis du trajet, ouverte depuis le contexte de la
  /// section (qui vit autant que l'écran), jamais celui du lien ou du bouton,
  /// que la liste relue peut démonter.
  void _openList() =>
      unawaited(openTripParcelsList(context, widget.announcementId));

  /// Fiche du colis [bidId], ouverte depuis le contexte de la section, jamais
  /// celui d'une ligne qu'une liste relue peut démonter.
  void _openParcel(String bidId) => unawaited(
    openTripParcel(context, tripId: widget.announcementId, bidId: bidId),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Titre et lien suivent la dernière liste reçue : gardés pendant un
    // rechargement ou après un échec.
    return BlocBuilder<BidBloc, BidState>(
      buildWhen: (previous, state) => state is BidListLoaded,
      builder: (context, state) {
        final total = state is BidListLoaded
            ? state.bids.where(isAcceptedTabBid).length
            : 0;
        return DetailCard(
          title: total > 0
              ? context.l10n.tripParcelsCardTitle(total)
              : context.l10n.tripOwnerParcelsSectionTitle,
          trailing: total > 0
              ? TextButton(
                  key: const Key('trip-parcels-see-list'),
                  onPressed: _openList,
                  // Aligné sur le bord droit du contenu de la carte (sans la
                  // marge intérieure du bouton), cible tactile de 44 dp gardée.
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                    textStyle: tt.labelLarge,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.l10n.tripParcelsSeeList,
                    maxLines: 1,
                    softWrap: false,
                  ),
                )
              : const SizedBox.shrink(),
          child: BlocBuilder<BidBloc, BidState>(
            builder: (context, state) {
              if (state is BidInitial || state is BidLoading) {
                return Padding(
                  padding: const EdgeInsets.all(DonySpacing.lg),
                  child: Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  ),
                );
              }
              if (state is BidListLoaded) {
                final embarked = state.bids
                    .where(isAcceptedTabBid)
                    .toList(growable: false);

                // Premier rendu de la liste chargée → tir analytics unique.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _logOnce(embarked.length);
                });

                if (embarked.isEmpty) {
                  return DonyEmptyState(
                    iconAsset: 'inbox',
                    title: context.l10n.tripOwnerNoParcelsMessage,
                    description: context.l10n.tripOwnerParcelsEmptyDescription,
                    padding: const EdgeInsets.symmetric(
                      vertical: DonySpacing.xl,
                    ),
                  );
                }

                final preview = tripParcelsPreview(embarked);
                final hidden = embarked.length - preview.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Résumé sur tous les colis, jamais sur les seules lignes
                    // montrées (FLUTTER-GS).
                    TripParcelsSummary(bids: embarked),
                    for (var i = 0; i < preview.length; i++) ...[
                      if (i > 0) const SizedBox(height: DonySpacing.sm),
                      _ColisRow(
                        bid: preview[i],
                        onTap: () => _openParcel(preview[i].id),
                      ),
                    ],
                    if (hidden > 0) ...[
                      const SizedBox(height: DonySpacing.md),
                      DonyButton(
                        key: const Key('trip-parcels-see-more'),
                        label: context.l10n.tripParcelsSeeMore(hidden),
                        variant: DonyButtonVariant.secondary,
                        onPressed: _openList,
                      ),
                    ],
                  ],
                );
              }
              // Liste en échec (hors ligne au premier chargement, ou
              // rechargement visible qui échoue) : sans « Réessayer », plus
              // aucun chemin ne mènerait aux colis du trajet.
              if (state is BidError) {
                return DonyEmptyState(
                  key: const Key('trip-parcels-load-error'),
                  type: DonyEmptyStateType.error,
                  iconAsset: 'circle-alert',
                  title: context.l10n.commonLoadError,
                  actionLabel: context.l10n.commonRetry,
                  onAction: () => context.read<BidBloc>().add(
                    BidListRequested(widget.announcementId),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}

/// Répartition des colis embarqués par étape du cycle réel, pour le résumé
/// de tête de section (FLUTTER-GS).
///
/// - en route : remis au voyageur ou en transit (`HANDED_OVER`, `IN_TRANSIT`) ;
/// - à récupérer : acceptés, pas encore remis (`ACCEPTED`). Un
///   `AWAITING_PAYMENT` n'y figure pas : l'expéditeur n'a pas encore payé,
///   le voyageur n'a rien à aller chercher ;
/// - arrivés : à destination, en attente de retrait (`ARRIVED`) ;
/// - livrés : remis au destinataire (`COMPLETED`).
///
/// Les clôturés (absence, refus, annulation) ne comptent dans aucun segment.
typedef TripParcelsCounts = ({
  int inTransit,
  int toCollect,
  int arrived,
  int delivered,
});

TripParcelsCounts tripParcelsCounts(Iterable<BidModel> bids) {
  var inTransit = 0, toCollect = 0, arrived = 0, delivered = 0;
  for (final b in bids) {
    switch (b.status) {
      case 'HANDED_OVER' || 'IN_TRANSIT':
        inTransit++;
      case 'ACCEPTED':
        toCollect++;
      case 'ARRIVED':
        arrived++;
      case 'COMPLETED':
        delivered++;
    }
  }
  return (
    inTransit: inTransit,
    toCollect: toCollect,
    arrived: arrived,
    delivered: delivered,
  );
}

/// Ligne de résumé en tête de « Colis dans le trajet » : « 3 colis en route
/// · 1 à récupérer · 2 livrés ». Segments vides omis ; rien si tous le sont.
/// Chiffres tabulaires en gras, lue d'un seul tenant par le lecteur d'écran.
class TripParcelsSummary extends StatelessWidget {
  const TripParcelsSummary({super.key, required this.bids});

  final List<BidModel> bids;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = tripParcelsCounts(bids);
    final segments = <(int, String)>[
      if (c.inTransit > 0)
        (c.inTransit, l.tripParcelsSummaryInTransit(c.inTransit)),
      if (c.toCollect > 0)
        (c.toCollect, l.tripParcelsSummaryToCollect(c.toCollect)),
      if (c.arrived > 0) (c.arrived, l.tripParcelsSummaryArrived(c.arrived)),
      if (c.delivered > 0)
        (c.delivered, l.tripParcelsSummaryDelivered(c.delivered)),
    ];
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    final base = tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final number = TextStyle(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final spoken = segments.map((e) => '${e.$1} ${e.$2}').join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.md),
      child: Semantics(
        label: spoken,
        excludeSemantics: true,
        child: Text.rich(
          key: const Key('trip-parcels-summary'),
          TextSpan(
            style: base,
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) const TextSpan(text: '  ·  '),
                TextSpan(text: '${segments[i].$1}', style: number),
                TextSpan(text: ' ${segments[i].$2}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne compacte d'un colis embarqué : miniature optionnelle, contenu, poids,
/// expéditeur et chip de statut. Tap → détail de l'offre (`/bids/:bidId`),
/// colis et trajet relus au retour.
class _ColisRow extends StatelessWidget {
  const _ColisRow({required this.bid, required this.onTap});

  final BidModel bid;
  final VoidCallback onTap;

  String? get _weightLabel {
    final w = bid.displayWeightKg;
    if (w == null) {
      return null;
    }
    return '${w.toStringAsFixed(w % 1 == 0 ? 0 : 1)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final content =
        (bid.contentCategory != null
            ? contentCategoriesDisplayName(context.l10n, bid.contentCategory!)
            : null) ??
        bid.description ??
        context.l10n.tripOwnerParcelsDefaultContent;
    final sender = bid.senderDisplayName(context.l10n);
    final weight = _weightLabel;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              if (bid.photos.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: CachedNetworkImage(
                      imageUrl: bid.photos.first.url,
                      cacheKey: DonyImage.stableCacheKey(bid.photos.first.url),
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          ColoredBox(color: cs.surfaceContainerHighest),
                      errorWidget: (_, _, _) => ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weight != null ? '$sender · $weight' : sender,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              _StatusChip(status: bid.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// Libellé traduit + couleur d'un statut de colis embarqué.
(String, Color) _statusMeta(
  String status,
  ColorScheme cs,
  AppLocalizations l,
) => switch (status) {
  'ACCEPTED' => (l.tripOwnerParcelsStatusAccepted, cs.primary),
  // Voyageur vient d'accepter une offre mobile money, en attente du
  // séquestre par l'expéditeur (30 min) — jamais la chaîne brute anglaise
  // (régression staging).
  'AWAITING_PAYMENT' => (l.tripOwnerParcelsStatusAwaitingPayment, cs.warning),
  'HANDED_OVER' => (l.tripOwnerParcelsStatusHandedOver, cs.warning),
  'IN_TRANSIT' => (l.tripOwnerParcelsStatusInTransit, cs.info),
  'ARRIVED' => (l.tripOwnerParcelsStatusArrived, cs.info),
  'COMPLETED' => (l.tripOwnerParcelsStatusDelivered, cs.success),
  'NO_SHOW' => (l.tripOwnerParcelsStatusNoShow, cs.error),
  'PARCEL_REFUSED' => (l.tripOwnerParcelsStatusParcelRefused, cs.error),
  'CANCELLED' => (l.tripOwnerParcelsStatusCancelled, cs.error),
  _ => (status, cs.onSurfaceVariant),
};

/// Petit chip de statut traduit pour un colis embarqué.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = _statusMeta(status, cs, context.l10n);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
