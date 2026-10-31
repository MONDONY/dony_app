import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/l10n/l10n.dart';

// Recherche d'un colis dans le sheet « Colis » de l'écran du trajet vu par
// son voyageur (`openTripActivitySheet`, `TripActivity.parcels`) : filtrage
// local, sans requête, par numéro de suivi, nom de l'expéditeur ou nom du
// destinataire.

/// Pause de saisie après laquelle une recherche est mesurée
/// (`trip_parcels_searched`).
const kTripParcelsSearchLogDelay = Duration(milliseconds: 800);

final _spaces = RegExp(r'\s+');

/// Espaces et tirets (trait d'union, tirets typographiques U+2010 à U+2015,
/// tiret bas) retirés d'un numéro de suivi : « DON-BGA8 WV2R » et
/// « donbga8wv2r » se valent.
final _trackingSeparators = RegExp(r'[\s\-_‐-―]');

/// [text] tel que la recherche le compare : sans espaces de bord, espaces
/// intérieurs réduits à un seul, minuscules, sans accents
/// ([normalizeSearch]). Vide : aucune recherche.
String tripParcelsSearchKey(String text) =>
    normalizeSearch(text.trim()).replaceAll(_spaces, ' ');

String _compactTracking(String text) =>
    normalizeSearch(text).replaceAll(_trackingSeparators, '');

/// Le colis [bid] répond-il à la recherche [query] ? Toujours vrai pour une
/// recherche vide. Sous-chaîne, insensible à la casse et aux accents, sur :
///
/// - le numéro de suivi, comparé sans espaces ni tirets, et SEULEMENT tel
///   que le voyageur a le droit de le voir ([travelerVisibleTrackingNumber] :
///   à partir de la remise). Un colis dont le numéro est masqué n'est jamais
///   trouvé par ce numéro : la recherche ne le révèle pas ;
/// - le nom de l'expéditeur affiché ([BidSenderName.senderDisplayName],
///   repli « Expéditeur » compris) ;
/// - le nom du destinataire, sauf quand la vue voyageur le masque
///   (destinataire en refus, [BidModel.recipientDeclined], comme
///   `ColisDestinataireCard`).
bool tripParcelMatches(AppLocalizations l, BidModel bid, String query) {
  final q = tripParcelsSearchKey(query);
  if (q.isEmpty) return true;
  final sender = tripParcelsSearchKey(bid.senderDisplayName(l));
  if (sender.contains(q)) return true;
  final recipient = bid.recipientDeclined ? null : bid.recipientName;
  if (recipient != null && tripParcelsSearchKey(recipient).contains(q)) {
    return true;
  }
  final tracking = travelerVisibleTrackingNumber(bid);
  final compactQuery = _compactTracking(q);
  return tracking != null &&
      compactQuery.isNotEmpty &&
      _compactTracking(tracking).contains(compactQuery);
}

/// Colis de [parcels] qui répondent à [query] ([tripParcelMatches]), dans
/// l'ordre reçu. Recherche vide : tous.
List<BidModel> tripParcelsMatching(
  AppLocalizations l,
  List<BidModel> parcels,
  String query,
) {
  if (tripParcelsSearchKey(query).isEmpty) return parcels;
  return [
    for (final b in parcels)
      if (tripParcelMatches(l, b, query)) b,
  ];
}
