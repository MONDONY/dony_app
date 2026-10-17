import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Jusqu'à trois réponses en un toucher, sous la question de l'IA.
class QuickReplies extends StatelessWidget {
  const QuickReplies({
    super.key,
    required this.replies,
    required this.onSelected,
  });

  final List<String> replies;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: DonySpacing.sm,
    runSpacing: DonySpacing.sm,
    children: [
      for (var i = 0; i < replies.length; i++)
        ActionChip(
          key: Key('ai-quick-reply-$i'),
          label: Text(replies[i]),
          onPressed: () => onSelected(replies[i]),
        ),
    ],
  );
}
