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
    this.alwaysAllowCustom = false,
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

  /// Voir [ContentCategoryComboBox.alwaysAllowCustom].
  final bool alwaysAllowCustom;

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
      alwaysAllowCustom: widget.alwaysAllowCustom,
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
/// - Tap sur un item = toggle ; la liste **se referme** et le champ se vide.
///   Pour en choisir un autre, on rouvre en retapant dans le champ. La
///   multi-sélection reste possible (les tags s'accumulent), mais chaque choix
///   est confirmé visuellement au lieu de laisser un panneau ouvert par-dessus
///   le reste du formulaire.
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
    this.alwaysAllowCustom = false,
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

  /// Propose toujours « Ajouter "X" » dès qu'on tape, même quand des items du
  /// catalogue matchent encore (tant que la saisie n'est pas un libellé exact
  /// déjà listé). Sinon la ligne d'ajout n'apparaît qu'une fois la liste
  /// filtrée vide. Utile là où l'expéditeur doit pouvoir saisir un contenu
  /// libre hors de la liste proposée (ex: formulaire d'envoi d'un colis).
  final bool alwaysAllowCustom;

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

  OverlayEntry? _overlayEntry;

  /// Position de défilement de la page pendant que la liste est ouverte.
  ///
  /// Le placement (au-dessus ou en dessous) et la hauteur disponible se
  /// calculent depuis la position du champ à l'écran. L'ouverture du clavier
  /// fait remonter le champ par une animation de défilement : sans réécoute,
  /// la décision resterait celle de la première frame, et la liste retomberait
  /// sous le clavier.
  ScrollPosition? _watchedScrollPosition;
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
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ContentCategoryComboBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = LinkedHashSet<String>.from(widget.selected);
    if (!setEquals(incoming, _selected)) {
      // Assignation directe : `didUpdateWidget` est déjà dans la phase de
      // build, le framework reconstruit ce widget juste après — un `setState`
      // ici serait redondant et interdit.
      _selected = incoming;
      _scheduleOverlayRebuild();
    } else if (!listEquals(widget.catalog, oldWidget.catalog)) {
      _scheduleOverlayRebuild();
    }
  }

  /// Reconstruit l'overlay hors de la phase de build courante.
  ///
  /// `markNeedsBuild()` sur l'`OverlayEntry` pendant que le parent se
  /// reconstruit (cas d'un rebuild déclenché par `selected` qui change alors
  /// que la liste est ouverte) lève « setState/markNeedsBuild called during
  /// build ». On le repousse au post-frame.
  void _scheduleOverlayRebuild() {
    final entry = _overlayEntry;
    if (entry == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_overlayEntry == entry) {
        entry.markNeedsBuild();
      }
    });
  }

  @override
  void dispose() {
    _watchedScrollPosition?.removeListener(_onScrolled);
    _watchedScrollPosition = null;
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

  void _emit() => widget.onChanged(_selected.toList());

  /// Suites communes à toute mutation de la sélection faite **depuis la
  /// liste** : on émet, on vide la saisie, et on referme.
  ///
  /// La fermeture passe par `unfocus()` plutôt que par un `_closeOverlay()`
  /// direct : sans lâcher le focus, le champ reste actif et le prochain
  /// `_onFocusChanged` ne se déclencherait jamais, laissant la liste
  /// définitivement close alors que le champ a l'air prêt à saisir.
  void _afterChange() {
    _emit();
    _controller.clear();
    // Rafraîchit le contenu du panneau le temps de son animation de sortie
    // (150 ms) : sans ça, il s'efface en affichant l'état d'avant le tap.
    _overlayEntry?.markNeedsBuild();
    _focusNode.unfocus();
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
    _watchedScrollPosition = Scrollable.maybeOf(context)?.position
      ?..addListener(_onScrolled);
    _animController.forward(from: 0);
  }

  void _onScrolled() => _overlayEntry?.markNeedsBuild();

  void _closeOverlay() {
    _watchedScrollPosition?.removeListener(_onScrolled);
    _watchedScrollPosition = null;
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

  /// Où poser la liste, et quelle hauteur lui laisser.
  ///
  /// La liste s'ouvrait toujours sous le champ, avec une hauteur plancher de
  /// 160 px même quand il ne restait rien dessous : clavier déployé, le champ
  /// remonte juste au-dessus du clavier et la liste passait dessous. On
  /// bascule au-dessus du champ dès que le dessous ne suffit plus.
  ({double maxHeight, bool above}) _dropdownPlacement(BuildContext context) {
    const margin = 16.0;
    const anchorGap = 6.0;
    const comfortable = 160.0;
    const floor = 96.0;
    const ceiling = 320.0;

    final mq = MediaQuery.of(context);
    final box = _fieldBoxKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return (maxHeight: ceiling, above: false);
    }

    final fieldTop = box.localToGlobal(Offset.zero).dy;
    final fieldBottom = fieldTop + box.size.height;
    final spaceBelow =
        mq.size.height -
        mq.viewInsets.bottom -
        fieldBottom -
        anchorGap -
        margin;
    final spaceAbove = fieldTop - mq.viewPadding.top - anchorGap - margin;

    // Bascule seulement si le dessous est vraiment à l'étroit ET que le dessus
    // fait mieux : sinon la liste sauterait d'un côté à l'autre à la frappe.
    final flip = spaceBelow < comfortable && spaceAbove > spaceBelow;
    final space = flip ? spaceAbove : spaceBelow;
    return (maxHeight: space.clamp(floor, ceiling), above: flip);
  }

  Widget _buildOverlay(BuildContext context) {
    final width = _fieldWidth;
    // Une seule évaluation du catalogue filtré, réutilisée pour la liste et la
    // décision d'afficher la ligne « Ajouter ».
    final filtered = _filteredCatalog;
    final query = _controller.text.trim();
    // La saisie est-elle déjà un libellé exact du catalogue ? Si oui, pas de
    // ligne d'ajout (l'item existe déjà, sélectionnable directement).
    final hasExactMatch = widget.catalog.any(
      (c) => c.label.toLowerCase() == query.toLowerCase(),
    );
    // Par défaut : ligne d'ajout seulement quand la liste filtrée est vide.
    // En mode [alwaysAllowCustom] : dès qu'on tape un contenu hors catalogue,
    // même si des items matchent encore — l'expéditeur peut toujours saisir
    // un élément libre.
    final showAddRow =
        query.isNotEmpty &&
        !hasExactMatch &&
        (filtered.isEmpty || widget.alwaysAllowCustom);
    final placement = _dropdownPlacement(context);
    // La liste glisse depuis le champ : vers le bas quand elle s'ouvre
    // dessous, vers le haut quand elle bascule au-dessus.
    final slide = Tween<Offset>(
      begin: Offset(0, placement.above ? 0.04 : -0.04),
      end: Offset.zero,
    ).animate(_fadeAnim);

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
          targetAnchor: placement.above
              ? Alignment.topLeft
              : Alignment.bottomLeft,
          followerAnchor: placement.above
              ? Alignment.bottomLeft
              : Alignment.topLeft,
          offset: Offset(0, placement.above ? -6 : 6),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: slide,
              child: Align(
                alignment: placement.above
                    ? Alignment.bottomLeft
                    : Alignment.topLeft,
                child: _ComboDropdown(
                  width: width,
                  maxHeight: placement.maxHeight,
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
          // Surtout pas de `keyboardDismissBehavior.onDrag` ici : cette liste
          // vit dans un overlay piloté par le focus du champ, donc refermer le
          // clavier au drag la ferait disparaître dès qu'on la fait défiler.
          child: SingleChildScrollView(
            key: Key('$keyPrefix-dropdown'),
            padding: const EdgeInsets.all(DonySpacing.xs),
            // Items du catalogue filtré PUIS, le cas échéant, la ligne
            // « Ajouter "X" ». Liste unifiée : quand la liste est vide seule
            // la ligne d'ajout reste, quand elle ne l'est pas l'ajout se pose
            // sous les correspondances (mode saisie libre).
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final category in catalog)
                  _ComboItem(
                    key: Key('$keyPrefix-item-${category.label}'),
                    category: category,
                    selected: selected.contains(category.label),
                    onTap: () => onToggle(category.label),
                  ),
                if (showAddRow)
                  _AddRow(
                    key: Key('$keyPrefix-item-add'),
                    query: query,
                    onTap: onAddCustom,
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
                if (selected) DonyIcon('check', size: 16, color: cs.primary),
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
            ),
          ),
        ],
      ),
    );
  }
}
