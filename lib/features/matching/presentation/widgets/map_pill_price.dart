import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:dony/l10n/l10n.dart';

/// Prix d'une pastille de la carte des trajets (`MarkerBitmapFactory`).
///
/// [pricePerKg] : prix au kilo de la carte de recherche, la sentinelle `<= 0`
/// étant rendue « Par article » (trajet à la grille seule). [priceLabel] :
/// prix déjà formé qui le remplace, pour un trajet bateau vendu au m³
/// (« 600 €/m³ »). [currency] : devise du trajet retenu.
typedef MapPillPrice = ({
  double pricePerKg,
  String? priceLabel,
  String currency,
});

/// Prix au m³ d'une pastille, comme la carte de recherche
/// ([tripPricePerM3Text]) : le prix de l'expéditeur, frais inclus, sinon le net
/// d'un back qui ne le sert pas. `null` hors trajet au m³.
double? _pricePerM3(AnnouncementModel a) =>
    a.isPricedPerM3 ? a.pricePerM3Display ?? a.pricePerM3 : null;

/// Pastille d'un trajet : son prix au kilo ; un trajet bateau vendu au m³
/// montre son prix au m³, jamais « Par article ».
MapPillPrice singlePillPrice(AppLocalizations l, AnnouncementModel a) {
  final perM3 = tripPricePerM3Text(l, a);
  return (
    pricePerKg: perM3 != null
        ? _pricePerM3(a) ?? 0
        : a.searchCardPricePerKg ?? 0,
    priceLabel: perM3,
    currency: a.currency,
  );
}

/// Pastille d'une pile de trajets à la même adresse : le moins cher au kilo.
///
/// On ne compare que les prix réellement présents : un `?? 0` par élément
/// ferait gagner « le moins cher » à une annonce sans prix face à une annonce
/// qui en a un, et ferait basculer toute la pile en « Par article » à tort.
/// Un trajet tarifé à la grille seulement a un prix au kilo à 0 : il ne passe
/// pas pour « le moins cher » de la pile (FLUTTER-PC). Sans aucun prix au
/// kilo, une pile qui compte des trajets bateau vendus au m³ montre le moins
/// cher au m³ ; sinon le premier trajet, rendu « Par article ».
MapPillPrice stackedPillPrice(
  AppLocalizations l,
  List<AnnouncementModel> items,
) {
  final withKgPrice = items.where((a) => (a.senderPricePerKg ?? 0) > 0);
  if (withKgPrice.isNotEmpty) {
    final cheapest = withKgPrice.reduce(
      (a, b) => a.senderPricePerKg! < b.senderPricePerKg! ? a : b,
    );
    return (
      pricePerKg: cheapest.searchCardPricePerKg ?? 0,
      priceLabel: null,
      currency: cheapest.currency,
    );
  }
  final perM3 = items.where((a) => a.isPricedPerM3);
  if (perM3.isNotEmpty) {
    final cheapest = perM3.reduce(
      (a, b) =>
          (_pricePerM3(a) ?? double.infinity) <=
              (_pricePerM3(b) ?? double.infinity)
          ? a
          : b,
    );
    return singlePillPrice(l, cheapest);
  }
  final first = items.first;
  return (
    pricePerKg: first.searchCardPricePerKg ?? 0,
    priceLabel: null,
    currency: first.currency,
  );
}
