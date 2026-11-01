import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_audience_line.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_detail_sections.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/l10n/l10n.dart';

/// Tuiles de la grille « Votre trajet » de l'écran du trajet vu par son
/// voyageur. Chacune ouvre un bottom sheet de lecture, éventuellement avec
/// une action (`openTripTileSheet`).
///
/// Le nom sert de valeur `tile` à `bid_detail_tile_opened` (`role:
/// trip_owner`) : ne pas le renommer sans migrer PostHog.
enum TripTile { itinerary, payments, conditions, poster, arrival }

/// Un colis du trajet est arrivé à destination (`ARRIVED`) : l'arrivée est
/// marquée et les instructions de retrait restent modifiables (le back
/// l'exige pour les modifier, `trip/not-arrived-yet`).
bool tripHasArrivedParcel(List<BidModel>? bids) =>
    bids?.any((b) => b.status == 'ARRIVED') ?? false;

/// Tuiles « Votre trajet » de [trip], dans l'ordre de la grille. Fonction
/// pure : l'écran la rappelle à chaque rechargement, et le sheet ouvert s'en
/// sert pour se fermer quand sa tuile n'a plus lieu d'être.
///
/// [bids] : colis du trajet chargés par l'écran (`BidListLoaded`), `null`
/// tant que la liste n'a pas répondu.
///
/// Une tuile n'apparaît que si son sheet a quelque chose à montrer :
/// - `itinerary` : un lieu de remise (dépôt ou récupération) ou une date
///   limite de dépôt ([TripPlacesSection.hasContent]), ou un voyage à
///   plusieurs étapes (`tripGroupId`) : ses étapes vivent dans ce sheet ;
/// - `payments` : au moins un moyen de paiement accepté
///   ([TripPaymentsSection.hasContent]) ;
/// - `conditions` : un type accepté, un type refusé ou une note aux
///   expéditeurs ([TripConditionsSection.hasContent]) ;
/// - `poster` : trajet partageable par son affiche ([canShareTripPoster],
///   ACTIVE) ;
/// - `arrival` : instructions de retrait non blanches ou au moins un colis
///   `ARRIVED` ([tripHasArrivedParcel]).
///
/// Aucune règle de statut pour `itinerary`, `payments` et `conditions` : un
/// trajet terminé, annulé, retiré par l'équipe (REMOVED_BY_ADMIN) ou d'un
/// statut inconnu de l'app les garde, en lecture.
///
/// [isOwner] faux (visiteur, ou propriété pas encore tranchée) : aucune
/// tuile, comme « À traiter » (`tripTodoTilesFor`), le pied et le menu ⋮.
List<TripTile> tripTilesFor({
  required AnnouncementModel trip,
  required List<BidModel>? bids,
  required bool isOwner,
}) {
  if (!isOwner) return const [];
  return [
    if (TripPlacesSection.hasContent(trip) || trip.tripGroupId != null)
      TripTile.itinerary,
    if (TripPaymentsSection.hasContent(trip)) TripTile.payments,
    if (TripConditionsSection.hasContent(trip)) TripTile.conditions,
    if (canShareTripPoster(trip)) TripTile.poster,
    if (ArrivalInstructionsCard.hasText(trip.arrivalInstructions) ||
        tripHasArrivedParcel(bids))
      TripTile.arrival,
  ];
}

/// Icône de la tuile (nom d'un SVG de `assets/icons`).
String tripTileIcon(TripTile tile) => switch (tile) {
  TripTile.itinerary => 'route',
  TripTile.payments => 'credit-card',
  TripTile.conditions => 'clipboard-check',
  TripTile.poster => 'share-2',
  TripTile.arrival => 'flag',
};

/// Titre de la tuile, repris en titre de son sheet.
String tripTileTitle(AppLocalizations l, TripTile tile) => switch (tile) {
  TripTile.itinerary => l.tripTileItinerary,
  TripTile.payments => l.tripTilePayments,
  TripTile.conditions => l.tripTileConditions,
  TripTile.poster => l.tripTilePoster,
  TripTile.arrival => l.tripTileArrival,
};

/// Résumé d'une ligne de la tuile, `null` quand il n'y a rien à résumer.
///
/// - `itinerary` : « Remise : {ville} · Retrait : {ville} » (la ville de
///   l'adresse, à défaut son libellé) ; sans lieu, la date limite de dépôt ;
/// - `payments` : les moyens acceptés (« Carte, Espèces, Mobile money ») ;
/// - `conditions` : « 3 types acceptés · 2 types refusés », à défaut ce qui
///   existe, ou « Note aux expéditeurs » s'il n'y a que la note ;
/// - `poster` : l'audience du trajet une fois chargée ([audience], « 12
///   personnes ont vu votre trajet », [TripAudience.tileSubtitle]), sinon
///   « Partager le trajet » ;
/// - `arrival` : « Instructions de retrait ».
String? tripTileSubtitle(
  AppLocalizations l,
  TripTile tile,
  AnnouncementModel trip, {
  TripAudienceState? audience,
}) {
  switch (tile) {
    case TripTile.itinerary:
      final pickup = trip.pickupAddress;
      final delivery = trip.deliveryAddress;
      final parts = [
        if (pickup != null)
          l.tripTileItineraryPickup(_place(pickup.city, pickup.label)),
        if (delivery != null)
          l.tripTileItineraryDelivery(_place(delivery.city, delivery.label)),
      ];
      if (parts.isNotEmpty) return parts.join(' · ');
      return trip.handoverDeadline != null
          ? tripHandoverDeadlineLabel(l, trip)
          : null;
    case TripTile.payments:
      final methods = [
        for (final m in trip.acceptedPaymentMethods) _methodLabel(l, m),
      ];
      return methods.isEmpty ? null : methods.join(', ');
    case TripTile.conditions:
      final accepted = trip.acceptedContentTypes?.length ?? 0;
      final refused = trip.refusedTypes?.length ?? 0;
      final parts = [
        if (accepted > 0) l.tripTileConditionsAccepted(accepted),
        if (refused > 0) l.tripTileConditionsRefused(refused),
      ];
      if (parts.isNotEmpty) return parts.join(' · ');
      return TripConditionsSection.hasNote(trip)
          ? l.listingSenderNoteTitle
          : null;
    case TripTile.poster:
      return TripAudience.tileSubtitle(l, audience) ?? l.tripTilePosterSubtitle;
    case TripTile.arrival:
      return l.tripOwnerArrivalEditingTitle;
  }
}

/// Ville de l'adresse, à défaut son libellé.
String _place(String? city, String label) {
  final c = city?.trim() ?? '';
  return c.isNotEmpty ? c : label;
}

String _methodLabel(AppLocalizations l, BidPaymentMethod m) => switch (m) {
  BidPaymentMethod.cash => l.paymentMethodCash,
  BidPaymentMethod.stripe => l.paymentMethodCard,
  BidPaymentMethod.mobileMoney => l.paymentMethodMobileMoney,
  BidPaymentMethod.wave => 'Wave', // i18n-ignore — nom de marque
  BidPaymentMethod.orangeMoney => 'Orange Money', // i18n-ignore — nom de marque
};
