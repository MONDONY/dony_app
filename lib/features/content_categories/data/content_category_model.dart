import 'package:flutter/material.dart';

/// Type de contenu d'un colis — source unique côté Flutter, pilotée par le
/// catalogue backend (`GET /config/content-categories`).
///
/// [code] est une clé technique — sert UNIQUEMENT au lookup d'icône locale
/// ([iconForCode]). Elle n'est JAMAIS envoyée au backend.
///
/// [label] est la valeur envoyée et stockée (comparée par le moteur de
/// matching backend — `BidContentRules`). C'est toujours [label] qui part
/// sur le wire, jamais [code], jamais `emoji + label`.
@immutable
class ContentCategory {
  const ContentCategory({
    required this.code,
    required this.label,
    required this.emoji,
  });

  factory ContentCategory.fromJson(Map<String, dynamic> json) =>
      ContentCategory(
        code: json['code'] as String,
        label: json['label'] as String,
        emoji: json['emoji'] as String,
      );

  final String code;
  final String label;
  final String emoji;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentCategory &&
          other.code == code &&
          other.label == label &&
          other.emoji == emoji);

  @override
  int get hashCode => Object.hash(code, label, emoji);

  @override
  String toString() => 'ContentCategory($code, $label, $emoji)';
}

/// Catalogue embarqué, identique au catalogue backend
/// (`GET /config/content-categories`). Filet de sécurité hors ligne : utilisé
/// quand l'appel réseau échoue, pour ne jamais bloquer un formulaire.
const List<ContentCategory> fallbackCatalog = [
  ContentCategory(
    code: 'DOCUMENTS',
    label: 'Documents & administratif',
    emoji: '📄',
  ),
  ContentCategory(
    code: 'ALIMENTATION_SECHE',
    label: 'Alimentation sèche',
    emoji: '🍚',
  ),
  ContentCategory(
    code: 'PRODUITS_FRAIS',
    label: 'Produits frais / périssables',
    emoji: '🐟',
  ),
  ContentCategory(
    code: 'COSMETIQUES',
    label: 'Cosmétiques & parfums',
    emoji: '💄',
  ),
  ContentCategory(code: 'VETEMENTS', label: 'Vêtements & tissus', emoji: '👗'),
  ContentCategory(code: 'CHAUSSURES', label: 'Chaussures', emoji: '👟'),
  ContentCategory(
    code: 'MEDICAMENTS_TRADITIONNELS',
    label: 'Médicaments traditionnels',
    emoji: '🌿',
  ),
  ContentCategory(
    code: 'ELECTRONIQUE',
    label: 'Téléphone & électronique',
    emoji: '📱',
  ),
  ContentCategory(code: 'LIVRES', label: 'Livres', emoji: '📚'),
  ContentCategory(code: 'CADEAUX', label: 'Cadeaux & jouets', emoji: '🎁'),
  ContentCategory(code: 'AUTRE', label: 'Autre', emoji: '📦'),
];

/// Icône Material locale pour un [code] technique, avec repli générique
/// ([Icons.inventory_2_rounded]) pour tout code inconnu — une nouvelle
/// catégorie ajoutée côté backend s'affiche donc sans release mobile.
IconData iconForCode(String code) {
  switch (code) {
    case 'DOCUMENTS':
      return Icons.description_rounded;
    case 'ALIMENTATION_SECHE':
      return Icons.bakery_dining_rounded;
    case 'PRODUITS_FRAIS':
      return Icons.set_meal_rounded;
    case 'COSMETIQUES':
      return Icons.spa_rounded;
    case 'VETEMENTS':
      return Icons.checkroom_rounded;
    case 'CHAUSSURES':
      return Icons.directions_walk_rounded;
    case 'MEDICAMENTS_TRADITIONNELS':
      return Icons.medical_services_rounded;
    case 'ELECTRONIQUE':
      return Icons.smartphone_rounded;
    case 'LIVRES':
      return Icons.menu_book_rounded;
    case 'CADEAUX':
      return Icons.card_giftcard_rounded;
    case 'AUTRE':
      return Icons.inventory_2_rounded;
    default:
      return Icons.inventory_2_rounded;
  }
}

/// Emoji associé à un [label] (libre ou canonique), résolu depuis le
/// catalogue embarqué ([fallbackCatalog]) — lookup synchrone, toujours
/// disponible hors ligne. 📦 par défaut pour un libellé libre inconnu.
String emojiForLabel(String? label) {
  for (final category in fallbackCatalog) {
    if (category.label == label) {
      return category.emoji;
    }
  }
  return '📦';
}

/// Découpe une chaîne `contentCategory` (libellés joints par virgule,
/// format wire) en liste de libellés propres.
List<String> splitContentCategoryLabels(String? raw) => (raw ?? '')
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();
