import 'package:dony/features/content_categories/data/content_category_datasource.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:flutter/foundation.dart';

abstract class IContentCategoryRepository {
  /// Catalogue depuis l'API, mis en cache en mémoire pour la session.
  /// En cas d'échec réseau, retourne [fallbackCatalog] — ne lève jamais :
  /// un formulaire ne doit jamais être bloqué par cet appel.
  Future<List<ContentCategory>> getCategories();
}

class ContentCategoryRepository implements IContentCategoryRepository {
  final ContentCategoryDatasource _datasource;
  List<ContentCategory>? _cache;

  ContentCategoryRepository(this._datasource);

  @override
  Future<List<ContentCategory>> getCategories() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    try {
      final categories = await _datasource.getContentCategories();
      _cache = categories;
      return categories;
    } catch (e) {
      debugPrint('[ContentCategoryRepository] fallback to embedded catalog: $e');
      return fallbackCatalog;
    }
  }
}
