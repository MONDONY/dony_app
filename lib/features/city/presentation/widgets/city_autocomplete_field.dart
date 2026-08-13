import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/recent_city_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Style visuel du champ.
///
/// - [outlined] : rendu historique, bordure Material + label flottant.
/// - [connected] : sans bordure propre, pensé pour être posé dans une carte
///   partagée (voir [CityFieldVariant.connected] dans `CityCorridorFields`) —
///   label toujours visible au-dessus, jamais superposé à un trait de
///   bordure (c'est ce chevauchement qui rendait le label illisible au repos
///   dans le rendu [outlined]).
enum CityFieldVariant { outlined, connected }

/// Hauteur fixe de la ligne de valeur en variant [CityFieldVariant.connected].
/// Assez haute pour contenir le bouton « x » (IconButton, ~34 dp) sans le
/// rogner, et identique qu'il y ait ou non une valeur saisie.
const double _connectedValueHeight = 36;

/// Champ de saisie avec autocomplétion de ville.
///
/// Les suggestions sont rendues **dans le flux scrollable** (Column enfant),
/// jamais via Overlay/OverlayEntry. Elles poussent le contenu vers le bas
/// et ne sont donc jamais masquées par un bouton sticky.
///
/// [fieldKey] est transmis au [TextField] interne — indispensable pour les
/// tests (finders stables) et pour distinguer départ vs arrivée.
class CityAutocompleteField extends StatefulWidget {
  const CityAutocompleteField({
    super.key,
    required this.label,
    required this.onSelected,
    this.initialValue,
    this.prefixIcon,
    this.fieldKey,
    this.requiredLabel = false,
    this.onCleared,
    this.errorText,
    this.recentRole,
    this.variant = CityFieldVariant.outlined,
    this.valueSuffix,
    this.onSuggestionsVisibilityChanged,
  });

  /// Message d'erreur affiché sous le champ (bordure rouge incluse).
  ///
  /// Optionnel, `null` par défaut : les appelants qui ne le fournissent pas
  /// gardent exactement le rendu historique.
  ///
  /// **Ignoré en variant [CityFieldVariant.connected]** : le message y est
  /// rendu par le parent sous la carte, voir `CityCorridorFields`.
  final String? errorText;

  final String label;
  final void Function(CityModel city) onSelected;

  /// Appelé quand l'utilisateur **vide** le champ, que ce soit par le bouton
  /// « x » interne ou en effaçant le texte à la main.
  ///
  /// Optionnel et nul par défaut : sans lui, le widget garde son comportement
  /// historique (seule une suggestion tapée remonte au parent). Les appelants
  /// qui ne le fournissent pas ne changent donc pas de comportement.
  final VoidCallback? onCleared;

  final String? initialValue;
  final Widget? prefixIcon;

  /// Key stable transmise au [TextField] interne.
  final Key? fieldKey;

  /// Rôle (départ/arrivée) utilisé pour mémoriser les 3 dernières villes
  /// sélectionnées via [RecentCityStore] : elles s'affichent dès le focus,
  /// tant que le champ est vide, et permettent de resélectionner un trajet
  /// fréquent sans requête réseau. Chaque sélection y est aussi enregistrée
  /// automatiquement.
  ///
  /// `null` par défaut : les appelants qui ne le fournissent pas gardent le
  /// comportement historique (aucune suggestion avant frappe, rien de mémorisé).
  final CityFieldRole? recentRole;

  /// Widget affiché juste après la valeur, sur la même ligne (ex : drapeau du
  /// pays) — rendu via `InputDecoration.suffix`, donc inline avec le texte
  /// (contrairement à [suffixIconConstraints] du bouton « x », plaqué en bout
  /// de champ). Ignoré en variant [CityFieldVariant.outlined].
  final Widget? valueSuffix;

  /// Si true, affiche un astérisque rouge (`cs.error`) après le label
  /// via `InputDecoration.label` (RichText) — même rendu que [DonyTextField.requiredLabel].
  final bool requiredLabel;

  /// Voir [CityFieldVariant].
  final CityFieldVariant variant;

  /// Notifie l'appelant à chaque ouverture/fermeture de la liste de
  /// suggestions (récents ou résultats serveur). Utile pour un parent qui
  /// superpose un élément à la carte : la liste pousse le contenu vers le bas,
  /// donc tout overlay positionné doit s'effacer le temps de la sélection —
  /// sinon il recouvre les suggestions et bloque le tap.
  ///
  /// Appelé **après** le frame (jamais pendant le build du parent).
  final ValueChanged<bool>? onSuggestionsVisibilityChanged;

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _ensureVisibleTimer;
  bool _suggestionsVisible = false;

  /// Remonte le changement d'état de la liste au parent, en différé : le calcul
  /// se fait pendant le build (voir [_buildSuggestions]), et prévenir un parent
  /// qui se reconstruit en réaction déclencherait un setState pendant le build.
  ///
  /// Le drapeau bascule avant la planification : au plus un rappel par
  /// transition réelle, jamais d'accumulation.
  void _notifySuggestions(bool visible) {
    if (_suggestionsVisible == visible) {
      return;
    }
    _suggestionsVisible = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSuggestionsVisibilityChanged?.call(visible);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) _controller.text = widget.initialValue!;
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(CityAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resynchronise le champ quand initialValue change depuis l'extérieur
    // (ex. application d'un modèle de trajet). On ne touche pas au contrôleur
    // si la valeur n'a pas changé, pour ne pas écraser la saisie en cours.
    final value = widget.initialValue;
    if (value != oldWidget.initialValue && value != _controller.text) {
      _controller.text = value ?? '';
    }
  }

  void _onFocusChanged() {
    setState(() {});
    if (_focusNode.hasFocus) {
      // Après le frame suivant, le clavier est en cours d'ouverture et le champ
      // peut être partiellement masqué — on le ramène dans la zone visible.
      // Un Timer annulable est utilisé pour attendre que les viewInsets du
      // clavier Android soient complètement stabilisés (≈ 300 ms) avant de
      // scroller — évite un scroll à la mauvaise position.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureVisibleTimer?.cancel();
        _ensureVisibleTimer = Timer(const Duration(milliseconds: 300), () {
          if (!mounted) {
            return;
          }
          Scrollable.maybeOf(context)?.position.ensureVisible(
            context.findRenderObject()!,
            alignment: 0.1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        });
      });
    }
  }

  @override
  void dispose() {
    _ensureVisibleTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCitySelected(CityModel city) {
    _controller.text = city.name;
    _focusNode.unfocus();
    context.read<CitySearchBloc>().add(const CitySearchCleared());
    final role = widget.recentRole;
    if (role != null) {
      unawaited(getIt<RecentCityStore>().add(role, city));
    }
    widget.onSelected(city);
  }

  /// Construit le widget label (avec astérisque rouge si [requiredLabel]).
  ///
  /// Délègue à [buildRequiredLabel] (design system partagé).
  Widget? _buildLabel(BuildContext context) => buildRequiredLabel(
    context,
    widget.label,
    isRequired: widget.requiredLabel,
  );

  Widget? _buildClearButton(ColorScheme cs) => _controller.text.isNotEmpty
      ? IconButton(
          tooltip: 'Effacer la ville',
          icon: DonyIcon('x', size: 18, color: cs.onSurfaceVariant),
          onPressed: () {
            _controller.clear();
            setState(() {});
            context.read<CitySearchBloc>().add(const CitySearchCleared());
            // Le champ visuellement vide DOIT vider le filtre côté parent,
            // sinon l'écran ment sur ce qui est appliqué.
            widget.onCleared?.call();
          },
        )
      : null;

  void _onChanged(String value) {
    setState(() {});
    context.read<CitySearchBloc>().add(CitySearchQueryChanged(value));
    if (value.isEmpty) {
      widget.onCleared?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.variant == CityFieldVariant.connected)
          _buildConnectedField(context, cs)
        else
          _buildOutlinedField(context, cs),
        // ── Suggestions — dans le flux scrollable (jamais en Overlay) ─────
        // Les suggestions poussent le contenu vers le bas : pas de masquage
        // par le bouton sticky "Continuer".
        _buildSuggestions(context),
      ],
    );
  }

  /// Rendu historique : bordure Material + label flottant sur la bordure.
  Widget _buildOutlinedField(BuildContext context, ColorScheme cs) {
    final labelWidget = _buildLabel(context);
    // Pas de ClipRRect/Container ici : le thème (InputDecorationTheme)
    // fournit déjà `filled` + OutlineInputBorder arrondi. Un ClipRRect
    // coupait la moitié haute du label flottant (centré sur la bordure
    // supérieure) → label illisible au focus. On laisse le décor au thème.
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      focusNode: _focusNode,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium!.copyWith(fontSize: 15, color: cs.onSurface),
      decoration: InputDecoration(
        // Si requiredLabel, label widget (RichText) ; sinon labelText.
        label: labelWidget,
        labelText: labelWidget == null ? widget.label : null,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: _buildClearButton(cs),
      ),
      onChanged: _onChanged,
    );
  }

  /// Rendu « connecté » : sans bordure propre, label statique toujours
  /// visible au-dessus d'une valeur en gros/gras — pensé pour être posé dans
  /// la carte « billet » partagée `CityCorridorFields` (style compagnie
  /// aérienne : rangée départ/arrivée, drapeau en [valueSuffix]).
  ///
  /// N'affiche pas [errorText] : dans cette variante le message est rendu par
  /// le parent, **sous** la carte. L'afficher ici allongerait la rangée en
  /// erreur, et les deux rangées doivent rester de hauteur égale (voir
  /// [_connectedValueHeight]).
  Widget _buildConnectedField(BuildContext context, ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    final labelStyle = tt.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );
    final label = widget.label.toUpperCase();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildRequiredLabel(
              context,
              label,
              isRequired: widget.requiredLabel,
              style: labelStyle,
            ) ??
            Text(label, style: labelStyle),
        // Hauteur figée : un champ rempli embarque le drapeau et le bouton
        // « x », un champ vide seulement du texte — sans ça la rangée remplie
        // est ~18 dp plus haute et la couture entre départ et arrivée n'est
        // plus au centre vertical de la carte, où `CityCorridorFields` pose
        // son bouton d'interversion. Mise à l'échelle avec la taille de texte
        // choisie par l'utilisateur (réglages d'accessibilité), sinon la
        // valeur est rognée dès les grands crans.
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(_connectedValueHeight),
          child: TextField(
            key: widget.fieldKey,
            controller: _controller,
            focusNode: _focusNode,
            style: tt.headlineMedium?.copyWith(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              isCollapsed: true,
              // Le thème global pose `filled: true` : sans ce false, le champ
              // peint son propre rectangle de fond par-dessus la rangée du
              // billet — visible comme une « boîte dans la boîte ».
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 3),
              hintText: 'Choisir une ville',
              hintStyle: tt.headlineMedium?.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
              suffix: widget.valueSuffix,
              suffixIcon: _buildClearButton(cs),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
            onChanged: _onChanged,
          ),
        ),
      ],
    );
  }

  /// Avant toute frappe, le focus seul affiche l'historique récent (si
  /// fourni) : c'est ce qui évite l'aller-retour réseau pour un trajet
  /// fréquent. Dès qu'une lettre est tapée, `_controller.text` n'est plus vide
  /// et on repasse sur les résultats serveur du [CitySearchBloc].
  Widget _buildSuggestions(BuildContext context) {
    final role = widget.recentRole;
    // Le rôle et le focus se testent avant de lire le magasin : hors focus ou
    // dès la première lettre tapée, la liste des récents n'est jamais affichée
    // et la décoder à chaque build serait du travail jeté.
    final recents =
        role != null && _focusNode.hasFocus && _controller.text.isEmpty
        ? getIt<RecentCityStore>().read(role)
        : const <CityModel>[];
    if (recents.isNotEmpty) {
      _notifySuggestions(true);
      return _RecentCityList(cities: recents, onTap: _onCitySelected);
    }
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<CitySearchBloc, CitySearchState>(
      builder: (ctx, state) {
        final Widget? suggestions = switch (state) {
          CitySearchLoading() => Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
            child: LinearProgressIndicator(color: cs.primary),
          ),
          CitySearchLoaded(:final cities) when cities.isNotEmpty => _ResultList(
            cities: cities,
            onTap: _onCitySelected,
          ),
          _ => null,
        };
        // Visibilité dérivée du rendu, pas ré-affirmée à chaque branche : une
        // branche ajoutée plus tard ne peut pas oublier de la mettre à jour.
        _notifySuggestions(suggestions != null);
        return suggestions ?? const SizedBox.shrink();
      },
    );
  }
}

/// Coque commune aux deux listes de suggestions (récents et résultats
/// serveur) : elles doivent rester visuellement indiscernables, une seule
/// décoration garantit qu'un ajustement les touche toutes les deux.
class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(
            color: cs.shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Ligne « ville + pays » d'une liste de suggestions. Seule l'icône de tête
/// distingue un récent (horloge) d'un résultat serveur (repère).
class _CitySuggestionTile extends StatelessWidget {
  const _CitySuggestionTile({
    required this.city,
    required this.leading,
    required this.onTap,
  });

  final CityModel city;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        leading: leading,
        title: Text(
          city.name,
          style: tt.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        subtitle: Text(
          city.countryName,
          style: tt.bodyMedium?.copyWith(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _RecentCityList extends StatelessWidget {
  const _RecentCityList({required this.cities, required this.onTap});

  final List<CityModel> cities;
  final void Function(CityModel) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return _SuggestionPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.md,
              DonySpacing.sm,
              DonySpacing.md,
              DonySpacing.xs,
            ),
            child: Text(
              'RÉCENTS',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          for (final city in cities)
            _CitySuggestionTile(
              city: city,
              leading: DonyIcon(
                'history',
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => onTap(city),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05);
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.cities, required this.onTap});

  final List<CityModel> cities;
  final void Function(CityModel) onTap;

  /// Hauteur max visible : ~4 suggestions. Au-delà la liste scrolle en interne.
  static const double _maxHeight = 224.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SuggestionPanel(
      // ConstrainedBox borne la hauteur à ~4 items — au-delà la liste scrolle.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxHeight),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: cities.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: cs.outline),
          itemBuilder: (ctx, i) {
            final city = cities[i];
            return _CitySuggestionTile(
              city: city,
              leading: Icon(DonyIcons.mapPin, color: cs.primary, size: 20),
              onTap: () => onTap(city),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05);
          },
        ),
      ),
    );
  }
}
