import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Variante du champ : texte (saisie clavier) ou tappable (picker).
enum _DonyTextFieldVariant { text, tappable }

/// Champ de formulaire dony.
///
/// Deux variantes :
/// - **Constructeur par défaut** — champ texte classique (TextFormField).
/// - **[DonyTextField.tappable]** — même habillage visuel, mais déclenche
///   [onTap] au lieu d'ouvrir le clavier (utilise `TextField(readOnly: true)`
///   pour garantir un rendu pixel-perfect identique sans dupliquer le style).
class DonyTextField extends StatelessWidget {
  // ── Constructeur texte ──────────────────────────────────────────────────────

  const DonyTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.errorText,
    this.enabled = true,
  })  : _variant = _DonyTextFieldVariant.text,
        _value = null,
        _onTap = null,
        _trailing = null;

  // ── Constructeur tappable ───────────────────────────────────────────────────

  /// Variante "tappable" : même habillage visuel que le champ texte, mais
  /// ouvre un picker (ou toute autre action) via [onTap] sans clavier.
  ///
  /// Approche : `TextField(readOnly: true, onTap: onTap)` avec la même
  /// [InputDecoration] que la variante texte — zéro duplication de style,
  /// rendu identique garanti par Flutter.
  ///
  /// - [label] : label flottant du champ.
  /// - [value] : valeur affichée. Si null/vide, [label] est rendu en hint.
  /// - [prefixIcon] : icône à gauche (même position que la variante texte).
  /// - [trailing] : widget optionnel à droite (ex : chevron ou icône picker).
  /// - [onTap] : callback déclenché au tap.
  const DonyTextField.tappable({
    super.key,
    this.label,
    String? value,
    this.prefixIcon,
    Widget? trailing,
    VoidCallback? onTap,
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
        enabled = true;

  // ── Champs partagés ─────────────────────────────────────────────────────────

  final _DonyTextFieldVariant _variant;

  // Texte
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final bool enabled;

  // Tappable
  final String? _value;
  final VoidCallback? _onTap;
  final Widget? _trailing;

  // ── Décoration partagée ─────────────────────────────────────────────────────

  InputDecoration _decoration({
    String? labelOverride,
    String? hintOverride,
    Widget? suffixOverride,
  }) {
    return InputDecoration(
      labelText: labelOverride ?? label,
      hintText: hintOverride ?? hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
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
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: _decoration(),
        );

      case _DonyTextFieldVariant.tappable:
        final hasValue = _value != null && _value.isNotEmpty;
        return TextField(
          // readOnly empêche le clavier ; onTap déclenche l'action picker.
          readOnly: true,
          onTap: _onTap,
          controller: hasValue
              ? TextEditingController(text: _value)
              : null,
          decoration: _decoration(
            // Quand aucune valeur : label joue le rôle de hint/placeholder.
            labelOverride: hasValue ? label : null,
            hintOverride: hasValue ? null : label,
            suffixOverride: _trailing,
          ),
        );
    }
  }
}
