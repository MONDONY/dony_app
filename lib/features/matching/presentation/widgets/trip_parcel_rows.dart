import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

// Pièces des colis du trajet vu par son voyageur, reprises par le sheet
// « Colis » (`openTripActivitySheet`) et la ligne Colis de l'écran
// (`TripParcelsLine`) : colis embarqués, résumé par étape du cycle, contenu
// et ligne d'un colis, ordre et libellés des statuts.

/// Colis embarqués du trajet parmi [bids] (onglet « Acceptées » de la liste
/// des colis, [isAcceptedTabBid]) : nombre, avatars et résumé de la ligne
/// Colis de l'écran, contenu du sheet « Colis ». Une seule source pour les
/// deux : la ligne et son sheet ne se contredisent jamais. `null` tant que
/// la liste n'a pas répondu.
List<BidModel>? tripEmbarkedParcels(List<BidModel>? bids) =>
    bids?.where(isAcceptedTabBid).toList(growable: false);

/// [embarked] avec d'abord les colis qui attendent un geste du voyageur
/// ([awaiting] : colis de « À traiter », `tripTodoParcelIds`, ceux que la
/// ligne compte en orange), puis les autres ; l'ordre reçu est gardé à
/// l'intérieur de chaque groupe (tri stable). Ordre des avatars de la ligne
/// Colis de l'écran.
List<BidModel> tripParcelsActionFirst(
  List<BidModel> embarked,
  Set<String> awaiting,
) => [
  ...embarked.where((b) => awaiting.contains(b.id)),
  ...embarked.where((b) => !awaiting.contains(b.id)),
];

/// Répartition des colis embarqués par étape du cycle réel, pour le résumé
/// du sheet « Colis » et la ligne Colis de l'écran (FLUTTER-GS).
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

/// Segments non vides du résumé des colis [c], dans l'ordre du cycle : le
/// nombre et son libellé (« colis en route », « à récupérer », « arrivés »,
/// « livrés »). Repris par le résumé du sheet « Colis »
/// ([TripParcelsSummary]) et le sous-titre de la ligne Colis de l'écran.
List<(int, String)> tripParcelsSummarySegments(
  AppLocalizations l,
  TripParcelsCounts c,
) => [
  if (c.inTransit > 0)
    (c.inTransit, l.tripParcelsSummaryInTransit(c.inTransit)),
  if (c.toCollect > 0)
    (c.toCollect, l.tripParcelsSummaryToCollect(c.toCollect)),
  if (c.arrived > 0) (c.arrived, l.tripParcelsSummaryArrived(c.arrived)),
  if (c.delivered > 0)
    (c.delivered, l.tripParcelsSummaryDelivered(c.delivered)),
];

/// Ligne de résumé en tête du sheet « Colis » : « 3 colis en route
/// · 1 à récupérer · 2 livrés » ([tripParcelsSummarySegments]). Segments
/// vides omis ; rien si tous le sont. Chiffres tabulaires en gras, lue d'un
/// seul tenant par le lecteur d'écran.
class TripParcelsSummary extends StatelessWidget {
  const TripParcelsSummary({super.key, required this.bids});

  final List<BidModel> bids;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final segments = tripParcelsSummarySegments(l, tripParcelsCounts(bids));
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

/// Contenu d'un colis ou d'une demande, tel que les listes du trajet le
/// montrent (ligne du sheet « Colis », carte de réponse directe, sheet des
/// demandes) : catégories déclarées, sinon description, sinon « Colis ». Une
/// valeur vide du back ne laisse jamais la ligne sans titre.
String tripParcelContent(AppLocalizations l, BidModel bid) {
  final category = bid.contentCategory;
  final categories = category == null
      ? ''
      : contentCategoriesDisplayName(l, category);
  final description = bid.description?.trim() ?? '';
  return categories.isNotEmpty
      ? categories
      : description.isNotEmpty
      ? description
      : l.tripOwnerParcelsDefaultContent;
}

/// Ligne compacte d'un colis embarqué : miniature optionnelle, contenu, poids,
/// expéditeur et chip de statut. Tap → détail de l'offre (`/bids/:bidId`),
/// colis et trajet relus au retour (`openTripParcel`), depuis le sheet
/// « Colis » de l'activité du trajet.
///
/// [awaitsAction] : le colis attend un geste du voyageur (« À traiter » de
/// l'écran du trajet) : un point orange avant la puce de statut, lu « attend
/// votre geste ».
class TripParcelRow extends StatelessWidget {
  const TripParcelRow({
    super.key,
    required this.bid,
    required this.onTap,
    this.awaitsAction = false,
  });

  final BidModel bid;
  final VoidCallback onTap;
  final bool awaitsAction;

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

    final content = tripParcelContent(context.l10n, bid);
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
              if (awaitsAction) ...[
                Semantics(
                  label: context.l10n.tripParcelAwaitingSemantics,
                  child: Container(
                    key: Key('trip-parcel-awaiting-${bid.id}'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cs.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
              ],
              _StatusChip(status: bid.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ordre métier des statuts de colis embarqués : celui des puces de filtre
/// du sheet « Colis » ; un statut inconnu passe après.
const kTripParcelStatusOrder = <String>[
  'ACCEPTED',
  'AWAITING_PAYMENT',
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'COMPLETED',
  'NO_SHOW',
  'PARCEL_REFUSED',
  'CANCELLED',
];

/// Libellé traduit + couleur d'un statut de colis embarqué (pastille d'une
/// ligne, puce de filtre).
(String, Color) tripParcelStatusMeta(
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
    final (label, color) = tripParcelStatusMeta(status, cs, context.l10n);
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
