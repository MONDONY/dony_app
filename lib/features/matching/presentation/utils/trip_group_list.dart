import 'package:dony/features/matching/data/models/announcement_model.dart';

/// Regroupement visuel des étapes d'un voyage dans « Mes trajets »
/// (FLUTTER-4D).
///
/// L'ordre de la liste est conservé, sauf que les étapes d'un même voyage
/// sont ramenées juste après la première rencontrée, dans l'ordre du voyage.
/// Un trajet isolé ne bouge pas.
List<AnnouncementModel> groupTripLegs(List<AnnouncementModel> items) {
  final byGroup = <String, List<AnnouncementModel>>{};
  for (final a in items) {
    final g = a.tripGroupId;
    if (g != null) (byGroup[g] ??= []).add(a);
  }
  for (final legs in byGroup.values) {
    legs.sort((a, b) => (a.tripLegIndex ?? 0).compareTo(b.tripLegIndex ?? 0));
  }
  final emitted = <String>{};
  final out = <AnnouncementModel>[];
  for (final a in items) {
    final g = a.tripGroupId;
    if (g == null) {
      out.add(a);
    } else if (emitted.add(g)) {
      out.addAll(byGroup[g]!);
    }
  }
  return out;
}

/// Vrai si [items][i] ouvre le bloc de son voyage (en-tête à afficher).
bool startsTripGroup(List<AnnouncementModel> items, int i) {
  final g = items[i].tripGroupId;
  if (g == null) return false;
  return i == 0 || items[i - 1].tripGroupId != g;
}

/// Vrai si [items][i] est suivi d'une autre étape du même voyage.
bool continuesTripGroup(List<AnnouncementModel> items, int i) {
  final g = items[i].tripGroupId;
  if (g == null || i + 1 >= items.length) return false;
  return items[i + 1].tripGroupId == g;
}

/// Itinéraire « Paris → Abidjan → Douala » des étapes visibles du voyage
/// [groupId] dans [items], dans l'ordre du voyage.
String tripGroupRoute(List<AnnouncementModel> items, String groupId) {
  final legs = items.where((a) => a.tripGroupId == groupId).toList()
    ..sort((a, b) => (a.tripLegIndex ?? 0).compareTo(b.tripLegIndex ?? 0));
  if (legs.isEmpty) return '';
  final cities = <String>[legs.first.departureCity];
  for (final leg in legs) {
    if (cities.last != leg.departureCity) cities.add(leg.departureCity);
    cities.add(leg.arrivalCity);
  }
  return cities.join(' → ');
}
