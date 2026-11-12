import 'package:dony/features/matching/data/models/item_size.dart';

/// Sentinelle de modification : effacer une taille déjà enregistrée.
const itemSizeClearWire = 'NONE';

/// Sentinelle de modification : effacer un poids max par colis déjà enregistré.
const maxParcelWeightClearWire = 0;

/// Intention d'écriture d'un champ facultatif, en modification.
///
/// Le back garde un champ ABSENT tel quel : « inchangé » ne s'envoie pas,
/// « effacé » s'envoie par une sentinelle ([itemSizeClearWire],
/// [maxParcelWeightClearWire]). Un simple `null` ne sait pas dire lequel des
/// deux, d'où ce type.
final class FieldChange<T extends Object> {
  /// Ne rien envoyer : le back conserve la valeur.
  const FieldChange.keep() : value = null, isClear = false;

  /// Envoyer [value].
  const FieldChange.set(T this.value) : isClear = false;

  /// Effacer la valeur enregistrée.
  const FieldChange.clear() : value = null, isClear = true;

  /// Création : une valeur renseignée est envoyée, `null` n'envoie rien.
  static FieldChange<T> ofNullable<T extends Object>(T? value) =>
      value == null ? FieldChange<T>.keep() : FieldChange<T>.set(value);

  /// Modification d'un formulaire complet : une valeur renseignée est
  /// envoyée, `null` efface (le formulaire dit « aucune »).
  static FieldChange<T> setOrClear<T extends Object>(T? value) =>
      value == null ? FieldChange<T>.clear() : FieldChange<T>.set(value);

  final T? value;
  final bool isClear;

  bool get isKeep => value == null && !isClear;
}

/// Entrée de corps pour une taille ([key] : `maxItemSize` d'un trajet, d'un
/// modèle ou d'une série, `itemSize` d'une demande ou d'une réservation).
/// Vide quand le champ est inchangé.
Map<String, Object> itemSizeEntry(String key, FieldChange<ItemSize> change) {
  final size = change.value;
  if (size != null) return {key: itemSizeToWire(size)};
  if (change.isClear) return {key: itemSizeClearWire};
  return const {};
}

/// Entrée de corps pour le poids max par colis. Vide quand inchangé ; `0`
/// pour effacer.
Map<String, Object> maxParcelWeightEntry(FieldChange<double> change) {
  final weight = change.value;
  if (weight != null) return {'maxParcelWeightKg': weight};
  if (change.isClear) return {'maxParcelWeightKg': maxParcelWeightClearWire};
  return const {};
}
