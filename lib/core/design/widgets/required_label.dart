import 'package:flutter/material.dart';

/// Construit un widget label avec un astérisque rouge si [isRequired].
///
/// Retourne null si [label] est null ou si [isRequired] est false — le caller
/// retombe alors sur [labelText] (String) pour la décoration classique.
///
/// Utilise [InputDecoration.label] (RichText) plutôt que [InputDecoration.labelText]
/// afin d'appliquer `cs.error` uniquement à l'astérisque tout en conservant
/// la couleur de label par défaut pour le reste du texte.
Widget? buildRequiredLabel(
  BuildContext context,
  String? label, {
  required bool isRequired,
}) {
  if (label == null || !isRequired) {
    return null;
  }
  final labelStyle = Theme.of(context).inputDecorationTheme.labelStyle ??
      Theme.of(context).textTheme.bodyMedium;
  return Text.rich(
    TextSpan(
      text: label,
      style: labelStyle,
      children: [
        TextSpan(
          text: ' *',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ),
  );
}
