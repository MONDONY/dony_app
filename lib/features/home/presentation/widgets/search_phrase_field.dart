import 'package:flutter/material.dart';

/// Champ de saisie du bloc « En une phrase ».
///
/// Le micro est un simple bouton pour l'instant : [onMicPressed] reste `null`
/// tant que la dictée (Task 4) n'est pas câblée, ce qui masque l'icône plutôt
/// que d'afficher un bouton mort.
class SearchPhraseField extends StatelessWidget {
  const SearchPhraseField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.onMicPressed,
    this.isParsing = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onMicPressed;
  final bool isParsing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      key: const Key('search-phrase-textfield'),
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      maxLength: 200,
      decoration: InputDecoration(
        counterText: '',
        hintText: '20 kilos à Bamako en mars',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: isParsing
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : (onMicPressed == null
                  ? null
                  : Semantics(
                      button: true,
                      label: 'Dicter votre recherche',
                      child: IconButton(
                        // 44 pt minimum : la cible tactile prime sur la compacité.
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: Icon(
                          Icons.mic_rounded,
                          color: cs.onTertiaryContainer,
                        ),
                        onPressed: onMicPressed,
                      ),
                    )),
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
      ),
    );
  }
}
