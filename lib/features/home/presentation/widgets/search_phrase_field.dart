import 'package:flutter/material.dart';

/// Champ de saisie du bloc « En une phrase ».
class SearchPhraseField extends StatelessWidget {
  const SearchPhraseField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.isParsing = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
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
            : null,
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
