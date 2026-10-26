import 'package:dony/core/storage/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Mémoire (propre à l'appareil, box Hive `user_prefs`) du choix de l'utilisateur
/// sur le filtre « Pour mes trajets » du mode Colis de l'accueil.
///
/// Le filtre s'active tout seul à l'ouverture du mode Colis pour un voyageur
/// qui a au moins un trajet actif. Dès que la personne le retire elle-même
/// (puce, écran de recherche), on s'en souvient : elle a refusé la valeur par
/// défaut, on ne la lui remet plus. Le reposer à la main efface ce refus.
class HomeMatchingDefaultStore {
  HomeMatchingDefaultStore(this._box);

  final Box<dynamic> _box;

  /// `true` quand l'utilisateur a retiré le filtre lui-même.
  bool get optedOut =>
      _box.get(HiveService.kHomeMatchingTripsOptedOut, defaultValue: false)
          as bool;

  Future<void> setOptedOut({required bool value}) =>
      _box.put(HiveService.kHomeMatchingTripsOptedOut, value);
}
