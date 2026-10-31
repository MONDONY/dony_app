import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_gain.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcel_rows.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Nombre maximal d'avatars de la ligne Colis.
const kTripParcelsLineFaces = 3;

/// Statuts où la ligne Colis s'affiche même sans colis : le trajet reçoit
/// des demandes ou transporte des colis, la ligne dit où ils apparaîtront.
const _alwaysShownStatuses = {'ACTIVE', 'FULL', 'IN_PROGRESS'};

/// Statuts sans ligne Colis : un brouillon (invisible des expéditeurs), un
/// trajet retiré par l'équipe (le back refuse de retirer un trajet qui a des
/// colis en vol).
const _neverShownStatuses = {'DRAFT', 'REMOVED_BY_ADMIN'};

/// La ligne Colis de l'écran du trajet s'affiche-t-elle ? Règle unique de la
/// ligne ([TripParcelsLine]) et de son sheet (qui se ferme seul quand elle
/// disparaît).
///
/// - ACTIVE, FULL, IN_PROGRESS : toujours, même sans colis ;
/// - DRAFT, REMOVED_BY_ADMIN : jamais ;
/// - COMPLETED, CANCELLED et statut inconnu de l'app : seulement si le
///   trajet a des colis. Liste chargée ([bids]) : un colis embarqué
///   ([tripEmbarkedParcels]) ; liste pas encore chargée : les colis comptés
///   par le détail (`confirmedParcelCount`, `parcelsSummary`). Les colis
///   remis d'un trajet annulé suivent la procédure de retour : la ligne
///   reste leur chemin.
bool tripParcelsLineShown(AnnouncementModel trip, List<BidModel>? bids) {
  if (_neverShownStatuses.contains(trip.status)) return false;
  if (_alwaysShownStatuses.contains(trip.status)) return true;
  final embarked = tripEmbarkedParcels(bids);
  if (embarked != null) return embarked.isNotEmpty;
  return trip.confirmedParcelCount > 0 || (trip.parcelsSummary?.count ?? 0) > 0;
}

/// Ce que montre la ligne Colis ([tripParcelsLineFor]).
typedef TripParcelsLineContent = ({
  /// Nombre de colis embarqués, `null` tant que la liste n'a pas répondu.
  int? count,

  /// Titre en gras : « N colis » (« Aucun colis », « Colis » sans liste),
  /// suivi de « · {gain estimé} » quand le gain est positif.
  String title,

  /// Sous-titre : segments non vides du résumé (« 4 colis en route · 2 à
  /// récupérer · 1 arrivé · 2 livrés ») ; sans colis, « Les colis acceptés
  /// apparaîtront ici. » ; `null` sans liste ou quand aucun segment ne
  /// s'applique (colis seulement en attente de paiement ou clôturés).
  String? subtitle,

  /// Colis dont l'avatar s'affiche (au plus [kTripParcelsLineFaces]), ceux
  /// qui attendent un geste du voyageur d'abord ([tripParcelsActionFirst]).
  /// Vide : une icône de colis à la place.
  List<BidModel> faces,
});

/// Contenu de la ligne Colis de [trip], `null` quand elle ne s'affiche pas
/// ([tripParcelsLineShown]). Fonction pure : l'écran la rappelle à chaque
/// rechargement.
///
/// [bids] : colis chargés par l'écran (`BidListLoaded`), `null` tant que la
/// liste n'a pas répondu. Le gain ([tripGainOf]) compte les colis récupérés,
/// espèces comprises ; sans liste, le net servi par le détail.
TripParcelsLineContent? tripParcelsLineFor({
  required AnnouncementModel trip,
  required List<BidModel>? bids,
  required AppLocalizations l,
}) {
  if (!tripParcelsLineShown(trip, bids)) return null;
  final embarked = tripEmbarkedParcels(bids);
  final gain = tripGainOf(trip, bids);
  final base = embarked == null
      ? l.tripOwnerParcelsTile
      : l.tripParcelsLineTitle(embarked.length);
  final title = gain.hasGain
      ? '$base · ${CurrencyFormatter.format(gain.total, SupportedCurrency.fromCodeOrDefault(gain.currency))}'
      : base;
  String? subtitle;
  if (embarked != null) {
    if (embarked.isEmpty) {
      subtitle = l.tripOwnerParcelsEmptyDescription;
    } else {
      final segments = tripParcelsSummarySegments(
        l,
        tripParcelsCounts(embarked),
      );
      subtitle = segments.isEmpty
          ? null
          : segments.map((s) => '${s.$1} ${s.$2}').join(' · ');
    }
  }
  return (
    count: embarked?.length,
    title: title,
    subtitle: subtitle,
    faces: embarked == null
        ? const []
        : tripParcelsActionFirst(
            embarked,
          ).take(kTripParcelsLineFaces).toList(growable: false),
  );
}

/// Ligne Colis de l'écran du trajet vu par son voyageur, sous « À traiter »
/// (choix « Une ligne colis » du 31/10) : une carte d'une ligne, bordure et
/// surface des cartes du corps (comme les lignes `TripTodoRows`). À gauche
/// les avatars des expéditeurs (initiales, jusqu'à trois, ceux qui
/// attendent un geste d'abord) ou une icône de colis sans colis ; le titre
/// « N colis · gain » et le résumé, chacun sur une ligne ; un chevron. Un
/// tap appelle [onOpen], qui ouvre le sheet « Colis » (gain détaillé en
/// tête, tous les colis).
///
/// Ne rend rien quand la ligne n'a pas lieu d'être ([tripParcelsLineShown]).
class TripParcelsLine extends StatelessWidget {
  const TripParcelsLine({
    super.key,
    required this.trip,
    required this.bids,
    required this.onOpen,
  });

  final AnnouncementModel trip;

  /// Colis chargés par l'écran, `null` tant que la liste n'a pas répondu.
  final List<BidModel>? bids;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final content = tripParcelsLineFor(trip: trip, bids: bids, l: l);
    if (content == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(DonyRadius.card);
    final subtitle = content.subtitle;
    return Semantics(
      button: true,
      label: subtitle == null ? content.title : '${content.title}. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: cs.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('trip-parcels-line'),
          onTap: onOpen,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                if (content.faces.isEmpty)
                  const DonyIconContainer(
                    key: Key('trip-parcels-line-icon'),
                    iconAsset: 'package',
                    size: DonyIconContainerSize.sm,
                  )
                else
                  _Faces(bids: content.faces),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        content.title,
                        key: const Key('trip-parcels-line-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          key: const Key('trip-parcels-line-subtitle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatars des expéditeurs (initiales, photo quand elle existe), qui se
/// chevauchent, chacun cerclé de la surface de la carte.
class _Faces extends StatelessWidget {
  const _Faces({required this.bids});

  final List<BidModel> bids;

  static const _size = 32.0;
  static const _ring = 2.0;
  static const _step = 22.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    const outer = _size + 2 * _ring;
    return SizedBox(
      key: const Key('trip-parcels-line-faces'),
      width: outer + _step * (bids.length - 1),
      height: outer,
      child: Stack(
        children: [
          for (final (i, bid) in bids.indexed)
            Positioned(
              left: _step * i,
              child: Container(
                key: Key('trip-parcels-line-face-${bid.id}'),
                padding: const EdgeInsets.all(_ring),
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                ),
                child: DonyAvatar(
                  name: bid.senderDisplayName(l),
                  imageUrl: bid.senderAvatarUrl,
                  size: DonyAvatarSize.sm,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
