import 'package:flutter/material.dart';

/// Catégories de contenu autorisées pour une demande de colis.
///
/// Source unique de vérité — remplace les `String` hardcodés disséminés
/// dans le code Dart (bottom sheet, wizard, repo).
///
/// `wireName` est ce qui passe sur le wire vers le back-end Spring Boot
/// (immutable — le back-end attend ces strings exactes).
enum ContentCategory {
  vetements('VETEMENTS', 'Vêtements', '👕', Icons.checkroom_rounded),
  medicaments('MEDICAMENTS', 'Médicaments', '💊', Icons.medical_services_rounded),
  alimentation('ALIMENTATION', 'Alim. sèche', '🍞', Icons.bakery_dining_rounded),
  hifi('HIFI', 'Hi-fi', '🎧', Icons.headphones_rounded),
  documents('DOCUMENTS', 'Documents', '📄', Icons.description_rounded),
  telephone('TELEPHONE', 'Téléphone', '📱', Icons.smartphone_rounded),
  cosmetiques('COSMETIQUES', 'Cosmét.', '💄', Icons.spa_rounded),
  cadeaux('CADEAUX', 'Cadeaux', '🎁', Icons.card_giftcard_rounded),
  autre('AUTRE', 'Autre', '📦', Icons.inventory_2_rounded);

  const ContentCategory(this.wireName, this.label, this.emoji, this.icon);

  /// String envoyée au back-end (ex: 'VETEMENTS').
  final String wireName;

  /// Libellé affiché à l'utilisateur (FR, ex: 'Vêtements').
  final String label;

  /// Emoji pour les fallback photos / chips légers.
  final String emoji;

  /// Icône Material pour les affichages plus "design".
  final IconData icon;

  /// Parse un `wireName` venant du back-end. Fallback sur `autre` si inconnu.
  ///
  /// Strict (lance) si tu veux détecter une rupture de contrat :
  /// utilise [ContentCategory.values.firstWhere] directement.
  static ContentCategory fromWire(String? s) {
    if (s == null || s.isEmpty) return ContentCategory.autre;
    for (final c in ContentCategory.values) {
      if (c.wireName == s) return c;
    }
    return ContentCategory.autre;
  }

  /// Médicaments → flag URGENT par défaut sur les cards de découverte.
  /// (Le back-end peut ajouter d'autres règles via un champ `priority` plus tard.)
  bool get isUrgent => this == ContentCategory.medicaments;
}
