import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:flutter/material.dart';

/// Sélecteur multiple réutilisable de types de contenu.
///
/// Liste déroulante à cocher alimentée par [repository] (catalogue backend,
/// avec repli hors ligne intégré — voir [IContentCategoryRepository]) +
/// champ « Ajouter un autre type… » pour la saisie libre.
///
/// Émet toujours une [List<String>] de LABELS (canoniques et/ou libres) via
/// [onChanged] — jamais de code technique, jamais `emoji + label`.
class ContentCategorySelector extends StatefulWidget {
  const ContentCategorySelector({
    super.key,
    required this.repository,
    required this.selected,
    required this.onChanged,
    this.freeTextHint = 'Ajouter un autre type…',
  });

  final IContentCategoryRepository repository;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String freeTextHint;

  @override
  State<ContentCategorySelector> createState() =>
      _ContentCategorySelectorState();
}

class _ContentCategorySelectorState extends State<ContentCategorySelector> {
  late final ValueNotifier<List<ContentCategory>> _catalogNotifier;
  late final ValueNotifier<Set<String>> _selectedNotifier;
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _catalogNotifier = ValueNotifier<List<ContentCategory>>(const []);
    _selectedNotifier = ValueNotifier<Set<String>>(widget.selected.toSet());
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final categories = await widget.repository.getCategories();
    if (!mounted) {
      return;
    }
    _catalogNotifier.value = categories;
  }

  @override
  void dispose() {
    _catalogNotifier.dispose();
    _selectedNotifier.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _toggle(String label) {
    final updated = Set<String>.from(_selectedNotifier.value);
    if (!updated.remove(label)) {
      updated.add(label);
    }
    _selectedNotifier.value = updated;
    widget.onChanged(updated.toList());
  }

  void _addCustom() {
    final value = _customCtrl.text.trim();
    if (value.isEmpty) {
      return;
    }
    final updated = Set<String>.from(_selectedNotifier.value)..add(value);
    _selectedNotifier.value = updated;
    widget.onChanged(updated.toList());
    _customCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ContentCategory>>(
      valueListenable: _catalogNotifier,
      builder: (context, catalog, _) {
        // Pendant le chargement (ou en cas de catalogue vide inattendu), on
        // affiche déjà le catalogue embarqué : le sélecteur n'est jamais vide
        // ni bloquant en attendant le réseau.
        final displayCatalog = catalog.isEmpty ? fallbackCatalog : catalog;
        return ValueListenableBuilder<Set<String>>(
          valueListenable: _selectedNotifier,
          builder: (context, selected, _) {
            final catalogLabels = displayCatalog.map((c) => c.label).toSet();
            final customSelected = selected
                .where((label) => !catalogLabels.contains(label))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final category in displayCatalog)
                  CheckboxListTile(
                    key: Key('content-category-${category.code}'),
                    value: selected.contains(category.label),
                    onChanged: (_) => _toggle(category.label),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${category.emoji} ${category.label}'),
                  ),
                for (final label in customSelected)
                  CheckboxListTile(
                    key: Key('content-category-custom-$label'),
                    value: true,
                    onChanged: (_) => _toggle(label),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(label),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('content-category-free-text'),
                        controller: _customCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _addCustom(),
                        decoration: InputDecoration(
                          hintText: widget.freeTextHint,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('content-category-add-btn'),
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _addCustom,
                      tooltip: 'Ajouter',
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
