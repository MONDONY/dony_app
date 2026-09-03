/// Les cinq outils qu'un utilisateur prépare une fois (spec § 2). L'ordre de
/// déclaration est celui du contrat serveur et celui du « prochain outil à
/// remplir » : ne pas le réordonner.
enum ToolKey {
  addresses('addresses'),
  recipients('recipients'),
  alerts('alerts'),
  tripTemplates('trip_templates'),
  priceGrid('price_grid');

  const ToolKey(this.apiKey);

  final String apiKey;

  static ToolKey? fromApiKey(String? key) {
    for (final k in values) {
      if (k.apiKey == key) return k;
    }
    return null;
  }
}

class ToolStatus {
  const ToolStatus({required this.key, required this.count});

  final ToolKey key;
  final int count;

  /// Binaire, au moins un élément (spec § 2). Recalculé ici plutôt que lu :
  /// un `ready` serveur incohérent avec `count` ne doit pas casser la carte.
  bool get ready => count > 0;
}

/// Réponse de `GET /users/me/tools-completion`.
///
/// Toujours cinq outils dans l'ordre de [ToolKey] : un outil absent de la
/// réponse (backend antérieur) compte pour zéro, une clé inconnue (backend
/// postérieur) est ignorée.
class ToolsCompletionModel {
  const ToolsCompletionModel({required this.tools});

  final List<ToolStatus> tools;

  factory ToolsCompletionModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['tools'] as List?) ?? const [];
    final counts = <ToolKey, int>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final key = ToolKey.fromApiKey(item['key'] as String?);
      if (key == null) continue;
      counts[key] = (item['count'] as num?)?.toInt() ?? 0;
    }
    return ToolsCompletionModel(
      tools: [
        for (final key in ToolKey.values)
          ToolStatus(key: key, count: counts[key] ?? 0),
      ],
    );
  }

  int get total => tools.length;

  int get ready => tools.where((t) => t.ready).length;

  bool get isComplete => ready == total;

  List<ToolKey> get missing =>
      tools.where((t) => !t.ready).map((t) => t.key).toList();

  ToolKey? get nextMissing => missing.isEmpty ? null : missing.first;

  int countOf(ToolKey key) => tools.firstWhere((t) => t.key == key).count;
}
