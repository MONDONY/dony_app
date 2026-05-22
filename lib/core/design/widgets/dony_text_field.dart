import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Variante du champ : texte (saisie clavier) ou tappable (picker).
enum _DonyTextFieldVariant { text, tappable }

/// Champ de formulaire dony.
///
/// Deux variantes :
/// - **Constructeur par défaut** — champ texte classique (TextFormField).
/// - **[DonyTextField.tappable]** — même habillage visuel, mais déclenche
///   [onTap] au lieu d'ouvrir le clavier (utilise `InputDecorator` pour un
///   rendu identique sans clavier ni `TextEditingController`).
class DonyTextField extends StatelessWidget {
  // ── Constructeur texte ──────────────────────────────────────────────────────

  const DonyTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.prefixIconColor,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.errorText,
    this.enabled = true,
    this.requiredLabel = false,
    this.autofocus = false,
  })  : _variant = _DonyTextFieldVariant.text,
        _value = null,
        _onTap = null,
        _trailing = null;

  // ── Constructeur tappable ───────────────────────────────────────────────────

  /// Variante "tappable" : même habillage visuel que le champ texte, mais
  /// ouvre un picker (ou toute autre action) via [onTap] sans clavier.
  ///
  /// Approche : `InkWell` + `InputDecorator` avec la même [InputDecoration]
  /// que la variante texte — zéro `TextEditingController`, zéro fuite de
  /// ressource, valeur toujours à jour à chaque rebuild.
  ///
  /// - [label] : label flottant du champ.
  /// - [value] : valeur affichée. Si null/vide, [label] est rendu en hint.
  /// - [prefixIcon] : icône à gauche (même position que la variante texte).
  /// - [prefixIconColor] : couleur de l'icône de préfixe. Si null, utilise
  ///   la couleur d'icône par défaut du thème. Passer `colorScheme.primary`
  ///   pour les champs « départ », `colorScheme.secondary` pour « arrivée ».
  /// - [trailing] : widget optionnel à droite (ex : chevron ou icône picker).
  /// - [onTap] : callback déclenché au tap.
  /// - [requiredLabel] : si true, ajoute un astérisque rouge (cs.error) au label.
  const DonyTextField.tappable({
    super.key,
    this.label,
    String? value,
    this.prefixIcon,
    this.prefixIconColor,
    Widget? trailing,
    VoidCallback? onTap,
    this.requiredLabel = false,
  })  : _variant = _DonyTextFieldVariant.tappable,
        _value = value,
        _onTap = onTap,
        _trailing = trailing,
        controller = null,
        hint = null,
        suffixIcon = null,
        obscureText = false,
        keyboardType = null,
        onChanged = null,
        validator = null,
        errorText = null,
        enabled = true,
        autofocus = false;

  // ── Champs partagés ─────────────────────────────────────────────────────────

  final _DonyTextFieldVariant _variant;

  // Texte
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;

  /// Couleur de l'icône de préfixe.
  ///
  /// `null` (défaut) → couleur d'icône du thème Material (aucune régression).
  /// Passer `colorScheme.primary` pour les champs « départ »,
  /// `colorScheme.secondary` pour les champs « arrivée ».
  final Color? prefixIconColor;

  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final bool enabled;
  final bool autofocus;

  // Tappable
  final String? _value;
  final VoidCallback? _onTap;
  final Widget? _trailing;

  /// Si true, affiche un astérisque rouge (`cs.error`) après le label via
  /// `InputDecoration.label` (RichText). Disponible dans les deux variantes.
  final bool requiredLabel;

  // ── Décoration partagée ─────────────────────────────────────────────────────

  /// Construit un widget label avec un astérisque rouge si [requiredLabel] est true.
  ///
  /// Délègue à [buildRequiredLabel] (design system partagé).
  Widget? _buildLabel(BuildContext context) =>
      buildRequiredLabel(context, label, isRequired: requiredLabel);

  InputDecoration _decoration(
    BuildContext context, {
    String? labelOverride,
    String? hintOverride,
    Widget? suffixOverride,
  }) {
    final labelWidget = _buildLabel(context);
    return InputDecoration(
      // Si requiredLabel, on passe un widget label (RichText avec asterisque
      // rouge) ; sinon on utilise labelText (String simple).
      label: labelWidget,
      labelText: labelWidget == null ? (labelOverride ?? label) : null,
      hintText: hintOverride ?? hint,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: prefixIconColor)
          : null,
      suffixIcon: suffixOverride ?? suffixIcon,
      errorText: errorText,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_variant) {
      case _DonyTextFieldVariant.text:
        return TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          enabled: enabled,
          autofocus: autofocus,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: _decoration(context),
        );

      case _DonyTextFieldVariant.tappable:
        final hasValue = _value != null && _value.isNotEmpty;
        // Utilise InputDecorator (la couche visuelle interne de TextField)
        // pour éviter tout TextEditingController — aucune fuite de ressource.
        // Le Text enfant reflète toujours la valeur courante à chaque rebuild.
        return InkWell(
          onTap: _onTap,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: InputDecorator(
            // isEmpty: true force le label en position hint/placeholder.
            isEmpty: !hasValue,
            decoration: _decoration(
              context,
              suffixOverride: _trailing,
            ),
            child: hasValue
                ? Text(
                    _value,
                    style: Theme.of(context).textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  )
                : const SizedBox.shrink(),
          ),
        );
    }
  }
}
