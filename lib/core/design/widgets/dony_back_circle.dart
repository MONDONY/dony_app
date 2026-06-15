import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dony/core/widgets/dony_icon.dart';

class DonyBackCircle extends StatelessWidget {
  const DonyBackCircle({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap ?? () => context.pop(),
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
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
    );
  }
}
