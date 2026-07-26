import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dony/core/widgets/dony_icon.dart';

class DonyBackCircle extends StatelessWidget {
  const DonyBackCircle({super.key, this.onTap, this.tooltip = 'Retour'});

  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap ?? () => context.pop(),
        customBorder: const CircleBorder(),
        child: Container(
          width: kDonyMinTapTarget,
          height: kDonyMinTapTarget,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surface,
            border: Border.all(color: cs.outline),
          ),
          child: DonyIcon('arrow-left',
            size: 20,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}
