import 'dart:collection';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Sélecteur multiple de types de contenu — combobox à liste déroulante.
///
/// Wrapper qui charge le catalogue depuis [repository] (cache + repli hors
/// ligne — voir [IContentCategoryRepository]) puis délègue le rendu à
/// [ContentCategoryComboBox]. Pendant le chargement (ou en cas de catalogue
/// vide inattendu), le catalogue embarqué ([fallbackCatalog]) est affiché :
/// le sélecteur n'est jamais vide ni bloquant en attendant le réseau.
///
/// Émet toujours une [List<String>] de LABELS (canoniques et/ou libres) via
/// [onChanged] — jamais de code technique, jamais `emoji + label`.
class ContentCategorySelector extends StatefulWidget {
  const ContentCategorySelector({
    super.key,
    required this.repository,
    required this.selected,
    required this.onChanged,
    this.hint = 'Ajouter un type de contenu…',
    this.keyPrefix = 'content-combo',
    this.singleSelection = false,
  });

  final IContentCategoryRepository repository;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String hint;

  /// Préfixe des [Key] internes — permet de distinguer plusieurs instances
  /// sur un même écran (ex: "accepté" vs "refusé") dans les tests.
  final String keyPrefix;

  /// Voir [ContentCategoryComboBox.singleSelection].
  final bool singleSelection;

  @override
  State<ContentCategorySelector> createState() =>
      _ContentCategorySelectorState();
}

class _ContentCategorySelectorState extends State<ContentCategorySelector> {
  List<ContentCategory>? _catalog;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await widget.repository.getCategories();
    if (!mounted) {
      return;
    }
    setState(() => _catalog = categories);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    return ContentCategoryComboBox(
      catalog: (catalog == null || catalog.isEmpty) ? fallbackCatalog : catalog,
      selected: widget.selected,
      onChanged: widget.onChanged,
      hint: widget.hint,
      keyPrefix: widget.keyPrefix,
      singleSelection: widget.singleSelection,
    );
  }
}

/// Combobox multi-sélection pur (contrôlé) — pas d'accès réseau.
///
/// - Les éléments sélectionnés s'affichent en tags supprimables au-dessus du
///   champ.
/// - Le focus sur le champ ouvre une liste déroulante (overlay ancré sous le
///   champ) listant tout [catalog] (emoji + label), avec un ✓ sur les items
///   déjà sélectionnés.
/// - Taper filtre la liste (insensible à la casse, espaces de bord ignorés).
/// - Tap sur un item = toggle ; la liste reste ouverte (multi-sélection) et
///   le champ se vide après chaque sélection.
/// - Si le texte tapé ne matche aucun item du catalogue, la liste affiche une
///   ligne « Ajouter "X" » qui ajoute X comme type libre.
/// - La liste se ferme au tap extérieur et à la perte de focus. Les tags
///   restent affichés indépendamment de l'état de la liste.
///
/// Émet toujours une [List<String>] de labels via [onChanged].
class ContentCategoryComboBox extends StatefulWidget {
  const ContentCategoryComboBox({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onChanged,
    this.hint = 'Ajouter un type de contenu…',
    this.keyPrefix = 'content-combo',
    this.singleSelection = false,
  });

  final List<ContentCategory> catalog;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String hint;
  final String keyPrefix;

  /// Choix exclusif : une nouvelle sélection remplace la précédente.
  ///
  /// Pensé pour les filtres de recherche, dont le critère « contenu » est une
  /// valeur unique côté requête. Volontairement un booléen et non un plafond
  /// `int` : le remplacement silencieux n'est acceptable qu'à un seul élément.
  /// Un vrai plafond à N devrait refuser l'ajout et le dire, comme le fait
  /// déjà l'étape 2 du wizard avec sa limite de 5.
  final bool singleSelection;

  @override
  State<ContentCategoryComboBox> createState() =>
      _ContentCategoryComboBoxState();
}

class _ContentCategoryComboBoxState extends State<ContentCategoryComboBox>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _fieldBoxKey = GlobalKey();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  OverlayEntry? _overlayEntry;
  late LinkedHashSet<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = LinkedHashSet<String>.from(widget.selected);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(_fadeAnim);
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ContentCategoryComboBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = LinkedHashSet<String>.from(widget.selected);
    if (!setEquals(incoming, _selected)) {
      _selected = incoming;
      if (mounted) {
        setState(() {});
      }
      _overlayEntry?.markNeedsBuild();
    } else if (!listEquals(widget.catalog, oldWidget.catalog)) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_controller.text == _query) {
      return;
    }
    setState(() => _query = _controller.text);
    _overlayEntry?.markNeedsBuild();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _openOverlay();
    } else {
      _closeOverlay();
    }
    setState(() {}); // rafraîchit la bordure focus du champ
  }

  List<ContentCategory> get _filteredCatalog {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.catalog;
    }
    return widget.catalog
        .where((c) => c.label.toLowerCase().contains(q))
        .toList();
  }

  bool get _showAddRow => _query.trim().isNotEmpty && _filteredCatalog.isEmpty;

  void _emit() => widget.onChanged(_selected.toList());

  /// Suites communes à toute mutation de la sélection.
  void _afterChange() {
    _emit();
    _controller.clear();
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    _overlayEntry?.markNeedsBuild();
  }

  /// Ajoute [label], en remplaçant la sélection courante si le composant est
  /// en choix exclusif.
  ///
  /// Le remplacement est préféré au refus : un tap doit toujours produire un
  /// effet visible.
  void _select(String label) {
    setState(() {
      if (widget.singleSelection) {
        _selected.clear();
      }
      _selected.add(label);
    });
    _afterChange();
  }

  void _toggle(String label) {
    if (_selected.contains(label)) {
      setState(() => _selected.remove(label));
      _afterChange();
      return;
    }
    _select(label);
  }

  void _addCustom() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    _select(value);
  }

  void _removeTag(String label) {
    setState(() => _selected.remove(label));
    _emit();
    _overlayEntry?.markNeedsBuild();
  }

  void _openOverlay() {
    if (_overlayEntry != null) {
      return;
    }
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward(from: 0);
  }

  void _closeOverlay() {
    final entry = _overlayEntry;
    if (entry == null) {
      return;
    }
    _overlayEntry = null;
    _animController.reverse().whenCompleteOrCancel(entry.remove);
  }

  double get _fieldWidth {
    final box = _fieldBoxKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.size.width;
    }
    return 280;
  }

  /// Hauteur maximale de la liste : bornée par l'espace réellement disponible
  /// sous le champ (moins une marge de sécurité), pour que la liste ne déborde
  /// jamais de l'écran et que le scroll interne soit visible/actif.
  double _dropdownMaxHeight(BuildContext context) {
    const margin = 16.0;
    const anchorGap = 6.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final box = _fieldBoxKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final fieldBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      final available =
          screenHeight - bottomInset - fieldBottom - anchorGap - margin;
      return available.clamp(160.0, 320.0);
    }
    return 320;
  }

  Widget _buildOverlay(BuildContext context) {
    final width = _fieldWidth;
    // Une seule évaluation : `_showAddRow` reparcourait `_filteredCatalog`,
    // donc les deux lectures pouvaient diverger.
    final filtered = _filteredCatalog;
    final query = _controller.text.trim();
    final showAddRow = query.isNotEmpty && filtered.isEmpty;
    final maxHeight = _dropdownMaxHeight(context);

    return Stack(
      children: [
        // Barrière transparente plein écran : ferme la liste au tap extérieur.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _focusNode.unfocus(),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(0, 6),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Align(
                alignment: Alignment.topLeft,
                child: _ComboDropdown(
                  width: width,
                  maxHeight: maxHeight,
                  catalog: filtered,
                  selected: _selected,
                  query: query,
                  showAddRow: showAddRow,
                  keyPrefix: widget.keyPrefix,
                  onToggle: _toggle,
                  onAddCustom: _addCustom,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isFocused = _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selected.isNotEmpty) ...[
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: _selected
                .map(
                  (label) => _ComboTag(
                    key: Key('${widget.keyPrefix}-tag-$label'),
                    label: label,
                    emoji: emojiForLabel(label),
                    onRemove: () => _removeTag(label),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: AnimatedContainer(
            key: _fieldBoxKey,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(
                color: isFocused ? cs.primary : cs.outline,
                width: isFocused ? 1.5 : 1,
              ),
            ),
            child: TextField(
              key: Key('${widget.keyPrefix}-field'),
              controller: _controller,
              focusNode: _focusNode,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base,
                  vertical: DonySpacing.md,
                ),
                suffixIcon: DonyIcon(
                  'chevron-down',
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Overlay dropdown ──────────────────────────────────────────────────────

class _ComboDropdown extends StatelessWidget {
  const _ComboDropdown({
    required this.width,
    required this.maxHeight,
    required this.catalog,
    required this.selected,
    required this.query,
    required this.showAddRow,
    required this.keyPrefix,
    required this.onToggle,
    required this.onAddCustom,
  });

  final double width;
  final double maxHeight;
  final List<ContentCategory> catalog;
  final Set<String> selected;
  final String query;
  final bool showAddRow;
  final String keyPrefix;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      shadowColor: DonyColors.shadow,
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: SizedBox(
        width: width,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          // Column eager (pas de lazy-build) : le catalogue est petit (~11
          // items) et les tests widgets doivent pouvoir trouver n'importe
          // quel item sans scroller manuellement au préalable.
          child: SingleChildScrollView(
            key: Key('$keyPrefix-dropdown'),
            padding: const EdgeInsets.all(DonySpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: showAddRow
                  ? [
                      _AddRow(
                        key: Key('$keyPrefix-item-add'),
                        query: query,
                        onTap: onAddCustom,
                      ),
                    ]
                  : [
                      for (final category in catalog)
                        _ComboItem(
                          key: Key('$keyPrefix-item-${category.label}'),
                          category: category,
                          selected: selected.contains(category.label),
                          onTap: () => onToggle(category.label),
                        ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Item de catalogue dans la liste déroulante — rayon interne concentrique
/// au rayon du conteneur de l'overlay (`DonyRadius.md` = `DonyRadius.sm` +
/// padding `DonySpacing.xs`). Hit area ≥ 44px.
class _ComboItem extends StatelessWidget {
  const _ComboItem({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ContentCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.xs,
        vertical: 2,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: selected ? cs.primary.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
            child: Row(
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    category.label,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                ),
                if (selected)
                  DonyIcon('check', size: 16, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne « Ajouter "X" » — remplace l'ancien bouton "+" de saisie libre.
class _AddRow extends StatelessWidget {
  const _AddRow({super.key, required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.xs,
        vertical: 2,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
            child: Row(
              children: [
                DonyIcon('plus', size: 16, color: cs.primary),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    'Ajouter « $query »',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tag supprimable ───────────────────────────────────────────────────────

/// Tag de sélection (au-dessus du champ) — compact, gabarit chip Material
/// (~32 px de haut) pour que plusieurs tags tiennent par ligne. Le ✕ garde
/// une zone tactile de 32×32 (pattern deleteIcon des chips denses), glyphe
/// 12 px.
class _ComboTag extends StatelessWidget {
  const _ComboTag({
    super.key,
    required this.label,
    required this.emoji,
    required this.onRemove,
  });

  final String label;
  final String emoji;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.only(left: DonySpacing.sm),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          // Flexible : un libellé long à 200 % passe à la ligne plutôt que
          // de déborder ; la hauteur minimale (au lieu de fixe) ci-dessus
          // lui laisse la place de grandir.
          Flexible(
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Semantics(
            button: true,
            container: true,
            excludeSemantics: true,
            label: 'Retirer cette catégorie',
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: DonyIcon('x', size: 12, color: cs.primary),
              ),
            ),
          )
          ),
        ],
      ),
    );
  }
}
