import 'package:dony/features/matching/data/models/tools_completion_model.dart';

/// Seule déclaration des libellés, routes et CTA par outil (spec § 4.5). Les
/// tuiles du hub gardent leurs propres libellés de titre : ici, uniquement ce
/// que la carte et les badges affichent.
extension ToolKeyPresentation on ToolKey {
  String get route => switch (this) {
    ToolKey.addresses => '/profile/addresses',
    ToolKey.recipients => '/profile/recipients',
    ToolKey.alerts => '/corridor-alerts',
    ToolKey.tripTemplates => '/trip-templates',
    ToolKey.priceGrid => '/profile/price-grid',
  };

  /// Groupe nominal au singulier avec article, pour la phrase des manquants.
  String get missingPhrase => switch (this) {
    ToolKey.addresses => 'une adresse',
    ToolKey.recipients => 'un destinataire',
    ToolKey.alerts => 'une alerte',
    ToolKey.tripTemplates => 'un modèle de trajet',
    ToolKey.priceGrid => 'une grille de prix',
  };

  String get ctaLabel => switch (this) {
    ToolKey.addresses => 'Ajouter une adresse',
    ToolKey.recipients => 'Ajouter un destinataire',
    ToolKey.alerts => 'Créer une alerte',
    ToolKey.tripTemplates => 'Créer un modèle de trajet',
    ToolKey.priceGrid => 'Remplir ma grille de prix',
  };

  /// Texte du badge « prêt ». La grille ne compte pas ses lignes : une grille
  /// à une ligne est aussi configurée qu'une grille à douze.
  String badgeLabel(int count) {
    if (this == ToolKey.priceGrid) return 'Configurée';
    final plural = count > 1 ? 's' : '';
    final noun = switch (this) {
      ToolKey.addresses => 'adresse',
      ToolKey.recipients => 'destinataire',
      ToolKey.alerts => 'alerte',
      ToolKey.tripTemplates => 'modèle',
      ToolKey.priceGrid => '',
    };
    return '$count $noun$plural';
  }
}

/// « Il vous manque un destinataire et une alerte. » Vide si rien ne manque.
String missingSentence(List<ToolKey> missing) {
  if (missing.isEmpty) return '';
  final parts = missing.map((k) => k.missingPhrase).toList();
  final joined = parts.length == 1
      ? parts.single
      : '${parts.sublist(0, parts.length - 1).join(', ')} et ${parts.last}';
  return 'Il vous manque $joined.';
}
