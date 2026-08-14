import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Champ d'adresse avec autocomplétion qui **préserve le texte libre**.
///
/// Contrairement à [AddressPickerField] (un `FormField` qui efface le texte au
/// blur tant qu'aucune suggestion n'est sélectionnée), ce champ est piloté par
/// un [TextEditingController] fourni par le parent : le texte saisi reste tel
/// quel même sans sélection — indispensable pour les adresses mal couvertes par
/// Google (quartiers africains) et pour pré-remplir une adresse existante sans
/// coordonnées.
///
/// Quand l'utilisateur choisit une suggestion, [onResolved] est appelé avec les
/// coordonnées résolues. Dès que le texte est ensuite modifié manuellement, les
/// coordonnées deviennent obsolètes : [onCoordinatesCleared] est appelé pour que
/// le parent les remette à null.
class AddressSuggestField extends StatefulWidget {
  const AddressSuggestField({
    super.key,
    required this.controller,
    required this.service,
    this.label,
    this.hint,
    this.prefixIcon,
    this.prefixIconAsset,
    this.prefixIconColor,
    this.onChanged,
    this.onResolved,
    this.onCoordinatesCleared,
  });

  final TextEditingController controller;
  final AddressAutocompleteService service;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;

  /// Variante Lucide du préfixe : si non-null, rend un [DonyIcon] avec cet
  /// asset au lieu de [prefixIcon]. Permet aux appelants de passer une icône
  /// Lucide tout en gardant la compatibilité avec l'API [IconData] existante.
  final String? prefixIconAsset;
  final Color? prefixIconColor;

  /// Appelé à chaque changement de texte (pour la validité côté parent).
  final ValueChanged<String>? onChanged;

  /// Appelé quand une suggestion est résolue (texte = libellé court, + lat/lng).
  final ValueChanged<AddressData>? onResolved;

  /// Appelé quand le texte est modifié après une résolution (coords obsolètes).
  final VoidCallback? onCoordinatesCleared;

  @override
  State<AddressSuggestField> createState() => _AddressSuggestFieldState();
}

class _AddressSuggestFieldState extends State<AddressSuggestField> {
  final _focus = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  Timer? _debounce;

  List<AddressSuggestion> _suggestions = [];
  bool _loading = false;
  bool _offline = false;
  bool _suppressListener = false;

  /// Verrou posé à la sélection d'une suggestion : empêche une requête déjà
  /// partie (debounce 300 ms) de rouvrir l'overlay qu'on vient de fermer.
  /// Levé dès que l'utilisateur retape ou revient dans le champ.
  bool _suppressSuggestions = false;

  // Texte de la dernière suggestion résolue : sert à détecter une édition
  // manuelle qui rend les coordonnées obsolètes.
  String? _resolvedText;

  String _lastText = '';

  // Jeton de session Google : généré à la première frappe, réinitialisé après
  // resolvePlace() ou quand le champ est vidé.
  String? _sessionToken;
  DateTime? _sessionTokenCreatedAt;

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onCtrlChanged);
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _debounce?.cancel();
    widget.controller.removeListener(_onCtrlChanged);
    _focus.dispose();
    super.dispose();
  }

  String _getOrCreateSessionToken() {
    final now = DateTime.now();
    if (_sessionToken == null ||
        _sessionTokenCreatedAt == null ||
        now.difference(_sessionTokenCreatedAt!) > const Duration(minutes: 3)) {
      _sessionToken = const Uuid().v4();
      _sessionTokenCreatedAt = now;
    }
    return _sessionToken!;
  }

  void _onCtrlChanged() {
    if (_suppressListener) {
      return;
    }
    final text = widget.controller.text;
    if (text == _lastText) {
      return; // sélection/curseur seulement
    }
    _lastText = text;
    // Frappe manuelle : l'utilisateur cherche autre chose, la liste peut
    // rouvrir.
    _suppressSuggestions = false;

    // Édition manuelle après une résolution → coords obsolètes.
    if (_resolvedText != null && text != _resolvedText) {
      _resolvedText = null;
      widget.onCoordinatesCleared?.call();
    }

    widget.onChanged?.call(text);
    _onTyped(text);
  }

  void _onTyped(String val) {
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      _removeOverlay();
      _sessionToken = null;
      _sessionTokenCreatedAt = null;
      setState(() {
        _suggestions = [];
        _offline = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetch(val));
  }

  Future<void> _fetch(String query) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final token = _getOrCreateSessionToken();
      final results = await widget.service.search(query, token);
      if (!mounted) {
        return;
      }
      setState(() {
        _suggestions = results;
        _loading = false;
      });
      if (_focus.hasFocus && results.isNotEmpty && !_suppressSuggestions) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } on DioException {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _offline = true;
      });
      _removeOverlay();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _offline = true;
      });
      _removeOverlay();
    }
  }

  Future<void> _selectSuggestion(AddressSuggestion s) async {
    _suppressSuggestions = true;
    _debounce?.cancel();
    _removeOverlay();
    if (mounted) {
      setState(() => _suggestions = []);
    }
    // Affiche immédiatement le libellé court (rue/quartier), texte libre conservé.
    _setText(s.mainText);
    widget.onChanged?.call(s.mainText);
    // Résout les coordonnées en arrière-plan (ferme la session Google).
    final token = _sessionToken ?? _getOrCreateSessionToken();
    try {
      final addr = await widget.service.resolvePlace(s.placeId, token);
      _sessionToken = null;
      _sessionTokenCreatedAt = null;
      if (!mounted) {
        return;
      }
      _resolvedText = s.mainText;
      widget.onResolved?.call(addr);
    } catch (_) {
      _sessionToken = null;
      _sessionTokenCreatedAt = null;
      // Échec de résolution : on garde le texte, sans coordonnées.
    }
  }

  void _setText(String text) {
    _suppressListener = true;
    try {
      widget.controller.text = text;
      _lastText = text;
    } finally {
      _suppressListener = false;
    }
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      _debounce?.cancel();
      _removeOverlay();
      setState(() => _suggestions = []);
    } else {
      _suppressSuggestions = false;
      setState(() {}); // bordure/label focus
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlay = OverlayEntry(
      builder: (ctx) => CompositedTransformFollower(
        link: _layerLink,
        targetAnchor: Alignment.bottomLeft,
        offset: const Offset(0, 4),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          shadowColor: DonyColors.shadow,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
                itemCount: _suggestions.length,
                separatorBuilder: (sepCtx, _) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(sepCtx).colorScheme.outline,
                  indent: 48,
                ),
                itemBuilder: (innerCtx, i) {
                  final s = _suggestions[i];
                  final tt = Theme.of(innerCtx).textTheme;
                  final ics = Theme.of(innerCtx).colorScheme;
                  return InkWell(
                    onTap: () => _selectSuggestion(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ics.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                DonyRadius.sm,
                              ),
                            ),
                            child: DonyIcon(
                              'map-pin',
                              size: 16,
                              color: ics.primary,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.mainText,
                                  style: tt.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (s.secondaryText.isNotEmpty)
                                  Text(
                                    s.secondaryText,
                                    style: tt.bodySmall?.copyWith(
                                      color: ics.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isFocused = _focus.hasFocus;
    final neutralIconColor = widget.prefixIconColor ?? cs.onSurfaceVariant;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(
                color: isFocused ? cs.primary : cs.outline,
                width: isFocused ? 1.5 : 1.0,
              ),
              color: cs.surface,
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              scrollPadding: const EdgeInsets.only(bottom: 280),
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: tt.bodyMedium?.copyWith(
                  color: isFocused ? cs.primary : cs.onSurfaceVariant,
                ),
                floatingLabelStyle: tt.bodySmall?.copyWith(
                  color: isFocused ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                hintText: widget.hint,
                hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(
                  DonySpacing.base,
                  DonySpacing.lg,
                  DonySpacing.base,
                  DonySpacing.md,
                ),
                prefixIcon:
                    (widget.prefixIcon == null &&
                        widget.prefixIconAsset == null)
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(
                          left: DonySpacing.md,
                          right: DonySpacing.xs,
                        ),
                        child: widget.prefixIconAsset != null
                            ? DonyIcon(
                                widget.prefixIconAsset!,
                                size: 18,
                                color: isFocused
                                    ? cs.primary
                                    : neutralIconColor,
                              )
                            : Icon(
                                widget.prefixIcon,
                                size: 18,
                                color: isFocused
                                    ? cs.primary
                                    : neutralIconColor,
                              ),
                      ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                suffixIcon: _loading
                    ? Padding(
                        padding: const EdgeInsets.all(DonySpacing.md),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          if (_offline)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DonyIcon('wifi-off', size: 12, color: cs.warning),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    "Connexion requise pour la recherche d'adresse",
                    style: TextStyle(color: cs.warning, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
