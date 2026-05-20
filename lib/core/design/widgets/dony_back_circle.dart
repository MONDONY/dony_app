import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        child: Icon(
          Icons.arrow_back_rounded,
          size: 20,
          color: cs.onSurface,
        ),
      ),
    );
  }
}
